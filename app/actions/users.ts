"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { z } from "zod";
import { revalidatePath } from "next/cache";

const createUserSchema = z.object({
  email: z.string().email("Email invalido"),
  password: z.string().min(12, "Password deve ter no minimo 12 caracteres"),
  nome: z.string().min(2, "Nome deve ter no minimo 2 caracteres"),
  papel: z.enum(["admin", "contabilista", "cliente"]),
  telemovel: z.string().optional(),
  organizacao_id: z.string().uuid(),
});

export type CreateUserState = {
  errors?: Record<string, string[]>;
  message?: string | null;
};

export async function createUser(prevState: CreateUserState, formData: FormData): Promise<CreateUserState> {
  const supabase = await createClient();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return { errors: { general: ["Nao autenticado"] }, message: "Acesso negado." };
  }

  // Com Custom Claims, o papel esta no JWT claims
  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  if (!["super_admin", "admin"].includes(papel)) {
    return { errors: { general: ["Permissao insuficiente"] }, message: "Acesso negado." };
  }

  const validated = createUserSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
    nome: formData.get("nome"),
    papel: formData.get("papel"),
    telemovel: formData.get("telemovel"),
    organizacao_id: formData.get("organizacao_id"),
  });

  if (!validated.success) {
    return {
      errors: validated.error.flatten().fieldErrors,
      message: "Dados invalidos.",
    };
  }

  const { email, password, nome, papel: novoPapel, telemovel, organizacao_id } = validated.data;

  // Usar admin client com Service Role Key
  const adminClient = createAdminClient();
  const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      nome,
      papel: novoPapel,
      organizacao_id,
    },
  });

  if (authError || !authData.user) {
    return {
      errors: { general: [authError?.message || "Erro ao criar utilizador"] },
      message: "Falha na criacao.",
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
    return {
      errors: { general: [dbError.message] },
      message: "Erro ao guardar na base de dados.",
    };
  }

  revalidatePath("/utilizadores");
  return { message: "Utilizador criado com sucesso." };
}