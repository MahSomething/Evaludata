import { criarEmpresa } from "@/app/actions/empresas";
import { EmpresaForm } from "@/components/ui/forms/empresa-form";

export default function NovaEmpresaPage() {
  return (
    <div className="max-w-xl">
      <h1 className="text-3xl font-bold mb-6">Nova Empresa</h1>
      <EmpresaForm action={criarEmpresa} />
    </div>
  );
}