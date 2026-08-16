"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AlertCircle } from "lucide-react";

type EmpresaFormProps = {
  action: (prevState: any, formData: FormData) => Promise<any>;
  defaultValues?: {
    nome?: string;
    nuit?: string;
    contacto?: string;
  };
};

const initialState = { success: false, error: null, data: null };

export function EmpresaForm({ action, defaultValues }: EmpresaFormProps) {
  const [state, formAction, isPending] = useActionState(action, initialState);

  return (
    <form action={formAction} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="nome">Nome da Empresa</Label>
        <Input
          id="nome"
          name="nome"
          defaultValue={defaultValues?.nome}
          required
          minLength={2}
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="nuit">NUIT</Label>
        <Input
          id="nuit"
          name="nuit"
          defaultValue={defaultValues?.nuit}
          required
          minLength={9}
          maxLength={9}
          placeholder="123456789"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="contacto">Contacto</Label>
        <Input
          id="contacto"
          name="contacto"
          defaultValue={defaultValues?.contacto}
          placeholder="+258 84 123 4567"
        />
      </div>

      {state.error && (
        <div className="flex items-center gap-2 text-sm text-danger bg-danger/10 p-3 rounded-md">
          <AlertCircle className="h-4 w-4" />
          <span>{state.error}</span>
        </div>
      )}

      <Button type="submit" disabled={isPending}>
        {isPending ? "A guardar..." : "Guardar"}
      </Button>
    </form>
  );
}
