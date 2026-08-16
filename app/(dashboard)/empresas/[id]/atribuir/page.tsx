import { notFound } from "next/navigation";
import {
  atribuirEmpresaContabilista,
  removerAtribuicaoContabilista,
  listarContabilistas,
  listarAtribuicoesEmpresa,
} from "@/app/actions/atribuicoes";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import Link from "next/link";
import { ArrowLeft, UserPlus, X } from "lucide-react";

export default async function AtribuirPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [contabilistasResult, atribuicoesResult] = await Promise.all([
    listarContabilistas(),
    listarAtribuicoesEmpresa(id),
  ]);

  if (!contabilistasResult.success || !atribuicoesResult.success) {
    return (
      <div className="space-y-6">
        <p className="text-danger">Erro ao carregar dados.</p>
      </div>
    );
  }

  const contabilistasDisponiveis = contabilistasResult.data || [];
  const atribuicoes = atribuicoesResult.data?.contabilistas || [];
  const atribuidosIds = new Set(atribuicoes.map((a: any) => a.contabilista_id));

  const naoAtribuidos = contabilistasDisponiveis.filter(
    (c: any) => !atribuidosIds.has(c.id)
  );

  return (
    <div className="space-y-6 max-w-xl">
      <div className="flex items-center gap-4">
        <Link href={`/empresas/${id}`}>
          <Button variant="ghost" size="sm">
            <ArrowLeft className="h-4 w-4 mr-1" />
            Voltar
          </Button>
        </Link>
      </div>

      <h1 className="text-2xl font-bold">Atribuir Contabilistas</h1>

      <div className="rounded-lg border">
        <div className="px-4 py-3 border-b bg-muted/50">
          <h2 className="font-semibold text-sm">Contabilistas Atribuidos</h2>
        </div>
        {atribuicoes.length === 0 ? (
          <div className="p-6 text-center text-sm text-muted-foreground">
            Nenhum contabilista atribuido a esta empresa.
          </div>
        ) : (
          <ul className="divide-y">
            {atribuicoes.map((a: any) => (
              <li key={a.id} className="px-4 py-3 flex items-center justify-between">
                <div>
                  <p className="font-medium text-sm">{a.utilizadores?.nome || "-"}</p>
                  <p className="text-xs text-muted-foreground">{a.utilizadores?.email || "-"}</p>
                </div>
                <form action={removerAtribuicaoContabilista.bind(null, a.id, id)}>
                  <Button variant="ghost" size="sm" className="text-danger hover:text-danger">
                    <X className="h-4 w-4" />
                  </Button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </div>

      {naoAtribuidos.length > 0 && (
        <form
          action={atribuirEmpresaContabilista}
          className="rounded-lg border p-4 space-y-4"
        >
          <h2 className="font-semibold text-sm">Adicionar Contabilista</h2>
          <input type="hidden" name="empresa_id" value={id} />
          <Select name="contabilista_id" required>
            <SelectTrigger>
              <SelectValue placeholder="Selecionar contabilista..." />
            </SelectTrigger>
            <SelectContent>
              {naoAtribuidos.map((c: any) => (
                <SelectItem key={c.id} value={c.id}>
                  {c.nome} ({c.email})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button type="submit" className="w-full">
            <UserPlus className="h-4 w-4 mr-2" />
            Atribuir Contabilista
          </Button>
        </form>
      )}
    </div>
  );
}