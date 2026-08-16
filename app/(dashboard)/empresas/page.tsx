import { listarEmpresas } from "@/app/actions/empresas";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export default async function EmpresasPage() {
  const result = await listarEmpresas();

  if (!result.success) {
    return <p className="text-danger">Erro: {result.error}</p>;
  }

  const empresas = result.data || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Empresas</h1>
        <Link href="/empresas/nova">
          <Button>Nova Empresa</Button>
        </Link>
      </div>

      {empresas.length === 0 ? (
        <div className="rounded-lg border bg-card p-8 text-center">
          <p className="text-muted-foreground">Nenhuma empresa registada.</p>
        </div>
      ) : (
        <div className="rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50">
                <th className="px-4 py-3 text-left font-medium">Nome</th>
                <th className="px-4 py-3 text-left font-medium">NUIT</th>
                <th className="px-4 py-3 text-left font-medium">Contacto</th>
                <th className="px-4 py-3 text-left font-medium">Estado</th>
                <th className="px-4 py-3 text-right font-medium">Acoes</th>
              </tr>
            </thead>
            <tbody>
              {empresas.map((empresa: any) => (
                <tr key={empresa.id} className="border-b last:border-0">
                  <td className="px-4 py-3">{empresa.nome}</td>
                  <td className="px-4 py-3">{empresa.nuit}</td>
                  <td className="px-4 py-3">{empresa.contacto || "-"}</td>
                  <td className="px-4 py-3">
                    <span className={empresa.ativa ? "text-success" : "text-muted-foreground"}>
                      {empresa.ativa ? "Ativa" : "Inativa"}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right space-x-2">
                    <Link href={`/empresas/${empresa.id}/editar`}>
                      <Button variant="ghost" size="sm">Editar</Button>
                    </Link>
                    <Link href={`/empresas/${empresa.id}/atribuir`}>
                      <Button variant="ghost" size="sm">Atribuir</Button>
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
