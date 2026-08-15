"use client";

import { useActionState } from "react";
import { login, type LoginState } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AlertCircle } from "lucide-react";

const initialState: LoginState = { message: null, errors: {} };

export default function LoginPage() {
  const [state, formAction, isPending] = useActionState(login, initialState);

  return (
    <div className="w-full max-w-md p-6 bg-background rounded-lg shadow-lg border">
      <h1 className="text-2xl font-semibold text-center mb-6">Aceder a Plataforma</h1>

      <form action={formAction} className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            name="email"
            type="email"
            placeholder="admin@empresa.pt"
            required
          />
          {state.errors?.email && (
            <p className="text-sm text-danger">{state.errors.email[0]}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input
            id="password"
            name="password"
            type="password"
            placeholder="************"
            required
            minLength={12}
          />
          {state.errors?.password && (
            <p className="text-sm text-danger">{state.errors.password[0]}</p>
          )}
        </div>

        {state.errors?.general && (
          <div className="flex items-center gap-2 text-sm text-danger bg-danger/10 p-3 rounded-md">
            <AlertCircle className="h-4 w-4" />
            <span>{state.errors.general[0]}</span>
          </div>
        )}

        <Button type="submit" className="w-full" disabled={isPending}>
          {isPending ? "A autenticar..." : "Entrar"}
        </Button>
      </form>
    </div>
  );
}