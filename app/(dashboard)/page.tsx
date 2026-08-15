import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const nome = user.user_metadata?.nome as string || user.email;
  const papel = user.user_metadata?.papel as string;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Bem-vindo, {nome}</h1>
        <p className="text-muted-foreground mt-1">
          Papel: <span className="capitalize">{papel.replace("_", " ")}</span>
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg border bg-card p-6">
          <p className="text-sm text-muted-foreground">Empresas</p>
          <p className="text-2xl font-bold mt-2">--</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <p className="text-sm text-muted-foreground">Documentos</p>
          <p className="text-2xl font-bold mt-2">--</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <p className="text-sm text-muted-foreground">Pendentes</p>
          <p className="text-2xl font-bold mt-2">--</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <p className="text-sm text-muted-foreground">Clientes</p>
          <p className="text-2xl font-bold mt-2">--</p>
        </div>
      </div>
    </div>
  );
}