import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";
import { LogOut } from "lucide-react";
import { logout } from "@/app/actions/auth";

export default async function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const papel = (user.app_metadata?.papel || user.user_metadata?.papel) as string;

  // Cliente nao acede ao dashboard
  if (papel === "cliente") {
    redirect("/portal");
  }

  return (
    <div className="min-h-screen flex">
      <aside className="w-64 border-r bg-background hidden lg:block">
        <div className="p-4 border-b">
          <span className="font-semibold text-lg">Evaludata</span>
          <p className="text-xs text-muted-foreground mt-1">{user.email}</p>
        </div>
        <nav className="p-4 space-y-1">
          <Link href="/" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Dashboard
          </Link>
          <Link href="/empresas" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Empresas
          </Link>
          <Link href="/documentos" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Documentos
          </Link>
          {papel !== "contabilista" && (
            <Link href="/utilizadores" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
              Utilizadores
            </Link>
          )}
          {(papel === "admin" || papel === "super_admin") && (
            <Link href="/aprovacoes" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
              Aprovacoes
            </Link>
          )}
          <Link href="/auditoria" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Auditoria
          </Link>
        </nav>

        <div className="p-4 border-t mt-auto">
          <form action={logout}>
            <Button type="submit" variant="ghost" className="w-full justify-start gap-2 text-sm">
              <LogOut className="h-4 w-4" />
              Sair
            </Button>
          </form>
        </div>
      </aside>

      <main className="flex-1 p-6">
        {children}
      </main>
    </div>
  );
}