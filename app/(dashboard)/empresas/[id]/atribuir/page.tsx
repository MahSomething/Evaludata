import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { atribuirEmpresaContabilista, listarContabilistas } from "@/app/actions/atribuicoes";
import { AtribuicaoForm } from "@/components/forms/atribuicao-form";

export default async function AtribuirPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  const supabase = await createClient();
  const { data: empresa } = await supabase
    .from("empresas")
    .select("id, nome")
    .eq("id", id)
    .single();

  if (!empresa) {
    notFound();
  }

  const contabilistasResult = await listarContabilistas();

  return (
    <div className="max-w-xl">
      <h1 className="text-3xl font-bold mb-2">Atribuir Empresa</h1>
      <p className="text-muted-foreground mb-6">{empresa.nome}</p>

      <AtribuicaoForm
        action={atribuirEmpresaContabilista}
        contabilistas={contabilistasResult.data || []}
        empresaId={id}
      />
    </div>
  );
}
