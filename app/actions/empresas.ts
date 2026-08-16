"use server";

import { createClient } from "@/lib/supabase/server";
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { logger, logAudit } from "@/lib/logger";

const empresaSchema = z.object({
  nome: z.string().min(2, "Nome deve ter no minimo 2 caracteres"),
  nuit: z.string().min(9, "NUIT invalido").max(9, "NUIT deve ter 9 digitos"),
  contacto: z.string().optional(),
  organizacao_id: z.string().uuid(),
});

const updateEmpresaSchema = empresaSchema.partial().omit({ organizacao_id: true });

export type EmpresaState = {
  success: boolean;
  error: string | null;
  data: { id?: string } | null;
};

export async function criarEmpresa(prevState: EmpresaState, formData: FormData): Promise<EmpresaState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  if (!["super_admin", "admin"].includes(papel)) {
    return { success: false, error: "Permissao insuficiente", data: null };
  }

  const validated = empresaSchema.safeParse({
    nome: formData.get("nome"),
    nuit: formData.get("nuit"),
    contacto: formData.get("contacto"),
    organizacao_id: formData.get("organizacao_id"),
  });

  if (!validated.success) {
    return { success: false, error: "Dados invalidos", data: null };
  }

  const { data, error } = await supabase
    .from("empresas")
    .insert({ ...validated.data, ativa: true })
    .select("id")
    .single();

  if (error) {
    logger.error("Erro ao criar empresa", new Error(error.message));
    return { success: false, error: error.message, data: null };
  }

  logAudit("criar_empresa", user.id, { empresaId: data.id });
  revalidatePath("/empresas");
  return { success: true, error: null, data: { id: data.id } };
}

export async function atualizarEmpresa(
  id: string,
  prevState: EmpresaState,
  formData: FormData
): Promise<EmpresaState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  if (!["super_admin", "admin"].includes(papel)) {
    return { success: false, error: "Permissao insuficiente", data: null };
  }

  const validated = updateEmpresaSchema.safeParse({
    nome: formData.get("nome"),
    nuit: formData.get("nuit"),
    contacto: formData.get("contacto"),
  });

  if (!validated.success) {
    return { success: false, error: "Dados invalidos", data: null };
  }

  const { error } = await supabase
    .from("empresas")
    .update(validated.data)
    .eq("id", id);

  if (error) {
    logger.error("Erro ao atualizar empresa", new Error(error.message));
    return { success: false, error: error.message, data: null };
  }

  logAudit("atualizar_empresa", user.id, { empresaId: id });
  revalidatePath("/empresas");
  return { success: true, error: null, data: null };
}

export async function eliminarEmpresa(id: string): Promise<EmpresaState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  if (!["super_admin", "admin"].includes(papel)) {
    return { success: false, error: "Permissao insuficiente", data: null };
  }

  const { error } = await supabase
    .from("empresas")
    .update({ ativa: false })
    .eq("id", id);

  if (error) {
    logger.error("Erro ao eliminar empresa", new Error(error.message));
    return { success: false, error: error.message, data: null };
  }

  logAudit("eliminar_empresa", user.id, { empresaId: id });
  revalidatePath("/empresas");
  return { success: true, error: null, data: null };
}

export async function listarEmpresas() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return { success: false, error: "Nao autenticado", data: null };
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;
  const organizacao_id = (user.app_metadata?.organizacao_id || user.user_metadata?.organizacao_id) as string;

  let query = supabase.from("empresas").select("*");

  if (papel === "admin") {
    query = query.eq("organizacao_id", organizacao_id);
  }

  const { data, error } = await query.order("nome");

  if (error) {
    logger.error("Erro ao listar empresas", new Error(error.message));
    return { success: false, error: error.message, data: null };
  }

  return { success: true, error: null, data };
}
