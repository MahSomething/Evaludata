import Link from "next/link";

export default function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <div className="min-h-screen flex">
      <aside className="w-64 border-r bg-background hidden lg:block">
        <div className="p-4 border-b">
          <span className="font-semibold text-lg">Evaludata</span>
        </div>
        <nav className="p-4 space-y-1">
          <Link href="/empresas" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Empresas
          </Link>
          <Link href="/documentos" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Documentos
          </Link>
          <Link href="/utilizadores" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Utilizadores
          </Link>
          <Link href="/aprovacoes" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Aprovacoes
          </Link>
          <Link href="/auditoria" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Auditoria
          </Link>
        </nav>
      </aside>

      <main className="flex-1 p-6">
        {children}
      </main>
    </div>
  );
}