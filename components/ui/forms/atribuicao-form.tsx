"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { AlertCircle } from "lucide-react";

type AtribuicaoFormProps = {
  action: (prevState: any, formData: FormData) => Promise<any>;
  contabilistas: Array<{ id: string; nome: string; email: string }>;
  empresaId: string;
};

const initialState = { success: false, error: null, data: null };

export function AtribuicaoForm({ action, contabilistas, empresaId }: AtribuicaoFormProps) {
  const [state, formAction, isPending] = useActionState(action, initialState);

  if (contabilistas.length === 0) {
    return <p className="text-muted-foreground">Nenhum contabilista disponivel.</p>;
  }

  return (
    <form action={formAction} className="space-y-4">
      <input type="hidden" name="empresa_id" value={empresaId} />

      <div className="space-y-2">
        <Label htmlFor="contabilista_id">Contabilista</Label>
        <select
          id="contabilista_id"
          name="contabilista_id"
          required
          className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background"
        >
          <option value="">Selecione...</option>
          {contabilistas.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nome} ({c.email})
            </option>
          ))}
        </select>
      </div>

      {state.error && (
        <div className="flex items-center gap-2 text-sm text-danger bg-danger/10 p-3 rounded-md">
          <AlertCircle className="h-4 w-4" />
          <span>{state.error}</span>
        </div>
      )}

      <Button type="submit" disabled={isPending}>
        {isPending ? "A atribuir..." : "Atribuir"}
      </Button>
    </form>
  );
}
