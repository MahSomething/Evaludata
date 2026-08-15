"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { logger, logAudit } from "@/lib/logger";

const createUserSchema = z.object({
  email: z.string().email("Email invalido"),
  nome: z.string().min(2, "Nome deve ter no minimo 2 caracteres"),
  papel: z.enum(["admin", "contabilista", "cliente"]),
  telemovel: z.string().optional(),
  organizacao_id: z.string().uuid(),
});

export type CreateUserState = {
  success: boolean;
  error: string | null;
  data: { id?: string; tempPassword?: string } | null;
};

function generateTempPassword(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
  let password = "";
  for (let i = 0; i < 16; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

export async function createUser(prevState: CreateUserState, formData: FormData): Promise<CreateUserState> {
  const supabase = await createClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papelCriador = (user.app_metadata?.papel || user.user_metadata?.papel) as string;

  // Validacao de permissao:
  // - Super Admin pode criar admin, contabilista, cliente
  // - Admin pode criar contabilista e cliente (se pode_registar_clientes)
  // - Contabilista e Cliente NAO podem criar
  if (!["super_admin", "admin"].includes(papelCriador)) {
    logger.warn("Unauthorized user creation attempt", { userId: user.id, papel: papelCriador });
    return { success: false, error: "Permissao insuficiente", data: null };
  }

  const validated = createUserSchema.safeParse({
    email: formData.get("email"),
    nome: formData.get("nome"),
    papel: formData.get("papel"),
    telemovel: formData.get("telemovel"),
    organizacao_id: formData.get("organizacao_id"),
  });

  if (!validated.success) {
    return {
      success: false,
      error: "Dados invalidos.",
      data: null,
    };
  }

  const { email, nome, papel: novoPapel, telemovel, organizacao_id } = validated.data;

  // Super Admin pode criar qualquer papel
  // Admin NAO pode criar outros Admins nem Super Admins
  if (papelCriador === "admin" && novoPapel === "admin") {
    return { success: false, error: "Admin nao pode criar outros Admins", data: null };
  }

  // Admin so pode criar clientes se a organizacao permite
  if (papelCriador === "admin" && novoPapel === "cliente") {
    const { data: org } = await supabase
      .from("organizacoes")
      .select("pode_registar_clientes")
      .eq("id", organizacao_id)
      .single();

    if (!org?.pode_registar_clientes) {
      return { success: false, error: "Organizacao nao permite registar clientes", data: null };
    }
  }

  // Admin so pode criar na sua propria organizacao
  if (papelCriador === "admin") {
    const criadorOrgId = (user.app_metadata?.organizacao_id || user.user_metadata?.organizacao_id) as string;
    if (criadorOrgId !== organizacao_id) {
      return { success: false, error: "Nao pode criar utilizadores noutra organizacao", data: null };
    }
  }

  const tempPassword = generateTempPassword();

  const adminClient = createAdminClient();
  const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
    email,
    password: tempPassword,
    email_confirm: true,
    user_metadata: {
      nome,
      papel: novoPapel,
      organizacao_id,
    },
  });

  if (authError || !authData.user) {
    logger.error("Failed to create user via admin API", authError || new Error("No user returned"), { email });
    return {
      success: false,
      error: "Erro ao criar utilizador. Tente novamente.",
      data: null,
    };
  }

  const { error: dbError } = await supabase.from("utilizadores").insert({
    id: authData.user.id,
    email,
    nome,
    papel: novoPapel,
    telemovel: telemovel || null,
    organizacao_id,
    ativo: true,
    criado_por: user.id,
  });

  if (dbError) {
    logger.error("Failed to insert user into database", new Error(dbError.message), { userId: authData.user.id });
    return {
      success: false,
      error: "Erro ao guardar na base de dados.",
      data: null,
    };
  }

  logAudit("criar_utilizador", user.id, {
    novoUserId: authData.user.id,
    email,
    papel: novoPapel,
    organizacao_id,
  });

  revalidatePath("/utilizadores");
  return {
    success: true,
    error: null,
    data: { id: authData.user.id, tempPassword },
  };
}