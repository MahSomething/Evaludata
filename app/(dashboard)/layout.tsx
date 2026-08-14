export default function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <div className="min-h-screen flex">
      {/* Sidebar */}
      <aside className="w-64 border-r bg-background hidden lg:block">
        <div className="p-4 border-b">
          <span className="font-semibold text-lg">Evaludata</span>
        </div>
        <nav className="p-4 space-y-1">
          <a href="/empresas" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Empresas
          </a>
          <a href="/documentos" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Documentos
          </a>
          <a href="/utilizadores" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Utilizadores
          </a>
          <a href="/aprovacoes" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Aprovacoes
          </a>
          <a href="/auditoria" className="block px-3 py-2 rounded-md hover:bg-muted text-sm">
            Auditoria
          </a>
        </nav>
      </aside>

      {/* Main content */}
      <main className="flex-1 p-6">
        {children}
      </main>
    </div>
  );
}
