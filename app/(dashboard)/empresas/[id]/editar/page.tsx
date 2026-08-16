import { atualizarEmpresa } from "@/app/actions/empresas";
import { EmpresaForm } from "@/components/ui/forms/empresa-form";
import { notFound } from "next/navigation";

export default async function EditarEmpresaPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { obterEmpresa } = await import("@/app/actions/empresas");
  const result = await obterEmpresa(id);

  if (!result.success || !result.data) {
    notFound();
  }

  const empresa = result.data.empresa;

  return (
    <div className="max-w-xl">
      <h1 className="text-3xl font-bold mb-6">Editar Empresa</h1>
      <EmpresaForm action={atualizarEmpresa.bind(null, id)} empresa={empresa} />
    </div>
  );
}