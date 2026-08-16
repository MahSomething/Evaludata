import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { atualizarEmpresa } from "@/app/actions/empresas";
import { EmpresaForm } from "@/components/forms/empresa-form";

export default async function EditarEmpresaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  const supabase = await createClient();
  const { data: empresa } = await supabase
    .from("empresas")
    .select("id, nome, nuit, contacto")
    .eq("id", id)
    .single();

  if (!empresa) {
    notFound();
  }

  const boundAction = atualizarEmpresa.bind(null, id);

  return (
    <div className="max-w-xl">
      <h1 className="text-3xl font-bold mb-6">Editar Empresa</h1>
      <EmpresaForm
        action={boundAction}
        defaultValues={{
          nome: empresa.nome,
          nuit: empresa.nuit,
          contacto: empresa.contacto || undefined,
        }}
      />
    </div>
  );
}
