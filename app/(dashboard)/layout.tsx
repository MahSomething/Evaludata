import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import Link from "next/link";
import { logout } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";
import {
  Building2,
  FileText,
  Users,
  CheckCircle,
  LogOut,
  LayoutDashboard,
} from "lucide-react";

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

  const papel = user.user_metadata?.papel as string;
  const nome = user.user_metadata?.nome as string || user.email;

  if (papel === "cliente") {
    redirect("/portal");
  }

  const navItems = [
    { href: "/", label: "Dashboard", icon: LayoutDashboard },
    { href: "/empresas", label: "Empresas", icon: Building2 },
    { href: "#", label: "Documentos", icon: FileText },
    { href: "#", label: "Utilizadores", icon: Users },
    { href: "#", label: "Aprovacoes", icon: CheckCircle },
  ];

  return (
    <div className="min-h-screen flex">
      <aside className="w-64 border-r bg-card hidden md:flex flex-col">
        <div className="p-6 border-b">
          <h2 className="text-lg font-bold">Evaludata</h2>
          <p className="text-xs text-muted-foreground mt-1">Gestao Documental</p>
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            >
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="p-4 border-t">
          <div className="mb-3">
            <p className="text-sm font-medium truncate">{nome}</p>
            <p className="text-xs text-muted-foreground capitalize">
              {papel.replace("_", " ")}
            </p>
          </div>
          <form action={logout}>
            <Button variant="outline" className="w-full" size="sm">
              <LogOut className="h-4 w-4 mr-2" />
              Sair
            </Button>
          </form>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="md:hidden border-b p-4 flex items-center justify-between">
          <h2 className="font-bold">Evaludata</h2>
          <form action={logout}>
            <Button variant="ghost" size="sm">
              <LogOut className="h-4 w-4" />
            </Button>
          </form>
        </header>
        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </div>
    </div>
  );
}