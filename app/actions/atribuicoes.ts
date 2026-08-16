"use server";

import { createClient } from "@/lib/supabase/server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { logger, logAudit } from "@/lib/logger";

const atribuicaoSchema = z.object({
  contabilista_id: z.string().uuid(),
  empresa_id: z.string().uuid(),
});

export type AtribuicaoState = {
  success: boolean;
  error: string | null;
  data: null;
};

export async function atribuirEmpresaContabilista(
  prevState: AtribuicaoState,
  formData: FormData
): Promise<AtribuicaoState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  if (!["super_admin", "admin"].includes(papel)) {
    return { success: false, error: "Permissao insuficiente", data: null };
  }

  const validated = atribuicaoSchema.safeParse({
    contabilista_id: formData.get("contabilista_id"),
    empresa_id: formData.get("empresa_id"),
  });

  if (!validated.success) {
    return { success: false, error: "Dados invalidos", data: null };
  }

  const { error } = await supabase.from("contabilista_empresas").insert({
    ...validated.data,
    atribuido_por: user.id,
  });

  if (error) {
    logger.error("Erro ao atribuir empresa", new Error(error.message));
    return { success: false, error: error.message, data: null };
  }

  logAudit("atribuir_empresa", user.id, validated.data);
  revalidatePath("/empresas");
  return { success: true, error: null, data: null };
}

export async function listarContabilistas() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const organizacao_id = (user.app_metadata?.organizacao_id || user.user_metadata?.organizacao_id) as string;

  const { data, error } = await supabase
    .from("utilizadores")
    .select("id, nome, email")
    .eq("organizacao_id", organizacao_id)
    .eq("papel", "contabilista")
    .eq("ativo", true);

  if (error) {
    return { success: false, error: error.message, data: null };
  }

  return { success: true, error: null, data };
}