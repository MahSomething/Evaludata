# CLAUDE.md

> Convenções técnicas e boas práticas para o projeto.
> Este ficheiro existe para que qualquer IA (ou developer) que interaja com o código não sugira padrões desatualizados ou incorretos.
> Última atualização: 2026-08-14

---

## 1. Versões Fixas da Stack

| Tecnologia | Versão | Nota |
|------------|--------|------|
| Next.js | 16.x | App Router é o único router suportado. Pages Router está em modo de manutenção. |
| React | 19.x | Server Components por padrão. |
| Node.js | 22 LTS | Mínimo para Next.js 16. |
| Tailwind CSS | v4 | Configuração via CSS (`@theme` em `globals.css`). **NUNCA** criar `tailwind.config.js`. |
| shadcn/ui | latest | Instalado via CLI: `npx shadcn@latest add [componente]`. Não é `npm install shadcn-ui`. |
| Supabase | latest | Usar `@supabase/ssr` para autenticação em Next.js. |
| TypeScript | 5.x | Obrigatório em todo o projeto. |

---

## 2. Estrutura de Pastas (App Router)

```
app/
├── (auth)/
│   ├── login/
│   │   └── page.tsx
│   └── layout.tsx
├── (dashboard)/
│   ├── layout.tsx              # Layout com sidebar/nav (admin/contabilista)
│   ├── page.tsx                # Dashboard redirect
│   ├── empresas/
│   ├── documentos/
│   ├── utilizadores/
│   └── aprovacoes/
├── (portal)/
│   ├── layout.tsx              # Layout minimalista (cliente)
│   └── page.tsx                # Portal do cliente
├── api/
│   └── ...                     # Route handlers apenas quando necessário
├── layout.tsx                  # Root layout
└── globals.css                 # Tailwind v4 config (@theme)
components/
├── ui/                         # Componentes shadcn/ui (nunca editar diretamente a não ser para customizar)
├── forms/                      # Formulários reutilizáveis
├── tables/                     # Tabelas com filtros
└── portal/                     # Componentes específicos do portal do cliente
lib/
├── supabase/
│   ├── client.ts               # createBrowserClient (cliente)
│   ├── server.ts               # createServerClient (server components / server actions)
│   └── proxy.ts                # createServerClient para middleware (renomeado de middleware.ts em Next.js 16)
├── storage/
│   └── r2.ts                   # Cliente S3 para R2 + funções de signed URL
├── whatsapp/
│   └── otp.ts                  # Envio de OTP via WhatsApp API
├── utils.ts                    # cn() e helpers
└── validators.ts               # Zod schemas para formulários
types/
└── database.ts                 # Tipos gerados pelo Supabase (supabase gen types)
supabase/
├── migrations/                 # Migrations versionadas (supabase db diff)
├── functions/                  # Edge Functions (cleanup, etc.)
└── seed.sql                    # Dados iniciais (Super Admin)
```

---

## 3. Regras de Componentes

### 3.1 Server Components por Padrão

- **TODAS** as páginas (`page.tsx`) e layouts (`layout.tsx`) são Server Components por padrão.
- **NUNCA** usar `'use client'` numa `page.tsx` ou `layout.tsx`.
- Usar Client Components **apenas** quando necessário:
  - Interatividade (hooks: `useState`, `useEffect`)
  - Eventos do browser (`onClick`, `onSubmit`)
  - APIs do browser (`localStorage`, `window`)
  - Formulários complexos (React Hook Form + Zod)

### 3.2 Padrão de Delegação

```tsx
// app/(dashboard)/empresas/page.tsx — SERVER COMPONENT
import { EmpresasTable } from "@/components/tables/empresas-table";
import { createClient } from "@/lib/supabase/server";

export default async function EmpresasPage() {
  const supabase = await createClient();
  const { data: empresas } = await supabase.from("empresas").select("*");

  return <EmpresasTable initialData={empresas} />;
}

// components/tables/empresas-table.tsx — CLIENT COMPONENT (se precisar de filtros)
'use client';

export function EmpresasTable({ initialData }) {
  const [filtro, setFiltro] = useState('');
  // ...
}
```

---

## 4. Supabase: Os 3 Clientes Obrigatórios

Usar **sempre** `@supabase/ssr`, nunca `@supabase/supabase-js` diretamente em Next.js.

### 4.1 Browser Client

```ts
// lib/supabase/client.ts
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!  // ou PUBLISHABLE_KEY
  );
}
```

### 4.2 Server Client

```ts
// lib/supabase/server.ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Ignorar erro se chamado de Server Component
          }
        },
      },
    }
  );
}
```

### 4.3 Proxy/Middleware Client

```ts
// lib/supabase/proxy.ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  await supabase.auth.getUser();
  return supabaseResponse;
}
```

**Nota:** Em Next.js 16, o ficheiro de middleware chama-se `proxy.ts` (não `middleware.ts`).

---

## 5. Tailwind CSS v4

### 5.1 Configuração

Toda a configuração fica em `app/globals.css`:

```css
@import "tailwindcss";

@theme {
  --color-primary: #0f172a;
  --color-secondary: #64748b;
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
  /* ... */
}
```

### 5.2 NÃO fazer

- ❌ Criar `tailwind.config.js` ou `tailwind.config.ts`
- ❌ Usar sintaxe v3 (`@tailwind base; @tailwind components; @tailwind utilities;`)
- ❌ Usar `theme.extend` — usar `@theme` diretamente

---

## 6. Row Level Security (RLS)

### 6.1 Regra de Ouro

**TODAS** as tabelas novas têm RLS ativado. **NUNCA** desativar RLS em produção.

### 6.2 Padrão de Policies com Custom Claims (OBRIGATÓRIO)

**NUNCA** usar subqueries aninhadas em RLS policies (ex: `organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())`).

**SEMPRE** usar Custom Claims no JWT do Supabase Auth:

```sql
-- Exemplo de policy CORRETA (rápida, sem subqueries)
CREATE POLICY "documentos_select" ON documentos
  FOR SELECT USING (
    organizacao_id = (auth.jwt() ->> 'organizacao_id')::uuid
    AND (
      (auth.jwt() ->> 'papel') = 'super_admin'
      OR (auth.jwt() ->> 'papel') = 'admin'
      OR (auth.jwt() ->> 'papel') = 'contabilista'
      OR (
        (auth.jwt() ->> 'papel') = 'cliente'
        AND estado = 'ativo'
      )
    )
  );
```

**Como injetar claims:**
```ts
// Server Action ou Edge Function com service role
await supabaseAdmin.auth.admin.updateUserById(userId, {
  app_metadata: {
    organizacao_id: "uuid-da-org",
    papel: "admin",
  },
});
```

**Regra:** Sempre que um utilizador muda de organização ou papel, atualizar as claims do JWT.

### 6.3 Service Role Key

A `SUPABASE_SERVICE_ROLE_KEY` **apenas** em:
- Edge Functions
- Server Actions que precisam de bypass de RLS (ex: criação de organização pelo Super Admin)
- Jobs de manutenção (ex: eliminação de documentos após 90 dias)

**NUNCA** expor a service role key no cliente.

---

## 7. Variáveis de Ambiente

```env
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Supabase agora chama isto "Publishable Key" em novos projetos
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# R2 (Cloudflare)
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET_NAME=documentos-consultoria
R2_PUBLIC_URL=https://pub-xxx.r2.dev

# WhatsApp API (ex: Evolution API, WPPConnect, ou Meta Business)
WHATSAPP_API_URL=https://evolution-api.exemplo.com
WHATSAPP_API_KEY=xxx
WHATSAPP_INSTANCE=instancia-principal
```

Nota: Em projetos Supabase mais recentes, a "anon key" pode aparecer como "publishable key" no dashboard. São a mesma coisa.

---

## 8. R2 Storage — Upload via Signed URLs (OBRIGATÓRIO)

**NUNCA** fazer upload de ficheiros via Server Actions (limite ~1-4MB).

**SEMPRE** usar o fluxo de Signed URLs:

1. Cliente pede signed URL ao servidor (Server Action)
2. Servidor gera URL temporária no R2 (S3 SDK, `PutObjectCommand`)
3. Cliente faz upload **direto** para o R2 (bypass do Next.js)
4. Cliente notifica servidor "upload completo" → servidor cria registo na BD

**Ver documento `STORAGE-R2.md` para implementação completa.**

---

## 9. Next.js 16: `await params` e `await searchParams`

Em Next.js 16, `params` e `searchParams` de `page.tsx` são **assíncronos**.

```tsx
// ❌ Antigo (Next.js 14/15)
export default function Page({ params }: { params: { id: string } }) {
  return <div>{params.id}</div>;
}

// ✅ Next.js 16
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <div>{id}</div>;
}
```

---

## 10. Supabase CLI + Migrations (OBRIGATÓRIO)

**NUNCA** criar tabelas manualmente no Supabase Studio sem gerar migration.

**Fluxo obrigatório:**
```bash
# 1. Fazer alterações no schema local (supabase/migrations/)
# 2. Gerar diff
supabase db diff -f nome_da_migration

# 3. Aplicar em produção
supabase db push

# 4. Gerar tipos TypeScript
supabase gen types typescript --project-id xxx > types/database.ts
```

**Ver documento `SUPABASE-SETUP.md` para configuração completa.**

---

## 11. Rate Limiting

Implementar rate limiting no `proxy.ts` para:
- Login/OTP (máx 5 tentativas / 15 min / IP)
- Upload de ficheiros (máx 10 uploads / hora / utilizador)

**Opção:** `lru-cache` no Edge Function ou `upstash/ratelimit` se usar Vercel.

---

## 12. Validação de Ficheiros (Segurança)

**Sempre** validar no servidor (Server Action):
- **Magic bytes** (primeiros bytes do ficheiro), não apenas extensão
- **Content-type** real (usar `file-type` package)
- **Tamanho máximo** (ex: 50MB)
- **Servir** com `Content-Disposition: attachment` para evitar execução inline

**NUNCA** confiar em `file.type` do browser (fácil de burlar).

---

## 13. Full-Text Search em Metadados (Nice-to-Have)

Sem OCR, usar PostgreSQL Full-Text Search nativo:

```sql
CREATE INDEX idx_documentos_search ON documentos
  USING gin(to_tsvector('portuguese', 
    coalesce(notas, '') || ' ' || 
    coalesce(ficheiro_nome, '') || ' ' ||
    coalesce(tipo_documento, '')
  ));
```

Pesquisa: `to_tsquery('portuguese', 'comparativo & iva & 2023')`

---

## 14. Supabase Realtime (Nice-to-Have)

Para notificações em tempo real (ex: badge de documentos pendentes no dashboard do Admin):

```ts
const channel = supabase
  .channel('documentos-pendentes')
  .on('postgres_changes', 
    { event: 'INSERT', schema: 'public', table: 'documentos', filter: 'estado=eq.pendente' },
    (payload) => { /* atualizar badge */ }
  )
  .subscribe();
```

---

## 15. Lista de NÃO FAZER

| Não fazer | Porquê |
|-----------|--------|
| ❌ Usar Pages Router | Obsoleto em Next.js 16 |
| ❌ Criar `middleware.ts` | Renomeado para `proxy.ts` em Next.js 16 |
| ❌ Criar `tailwind.config.js` | Tailwind v4 usa CSS config |
| ❌ Usar `@supabase/supabase-js` diretamente em Next.js | Usar `@supabase/ssr` |
| ❌ Desativar RLS em tabelas | Quebra de segurança em multi-tenant |
| ❌ Fazer queries Supabase em Client Components sem validação | Expor dados indevidamente |
| ❌ Usar `useEffect` para fetch inicial de dados | Usar Server Components + `await` |
| ❌ Guardar secrets em `localStorage` | Usar cookies httpOnly via Supabase Auth |
| ❌ Fazer upload direto para Supabase Storage sem validação de tipo/tamanho | Validar no server action antes |
| ❌ Usar `any` em TypeScript | Tipar tudo, incluir `types/database.ts` do Supabase |
| ❌ Fazer upload via Server Action (ficheiros > 1MB) | Usar signed URLs do R2 |
| ❌ Usar subqueries em RLS policies | Usar Custom Claims no JWT |
| ❌ Criar tabelas em produção sem migration | Usar Supabase CLI sempre |
| ❌ Confiança em `file.type` do browser | Validar magic bytes no servidor |

---

## 16. Convenções de Código

- **Nomenclatura:**
  - Componentes React: PascalCase (`EmpresasTable`)
  - Funções/helpers: camelCase (`getEmpresas`)
  - Tabelas BD: snake_case, plural (`empresas`, `documentos`)
  - Colunas BD: snake_case (`criado_em`, `organizacao_id`)
  - Variáveis de ambiente: SCREAMING_SNAKE_CASE

- **Async/await:** Preferir sobre `.then()` em todo o código moderno.
- **Error handling:** Usar `try/catch` em Server Actions. Retornar objetos `{ success: boolean, error?: string, data?: T }`.
- **Validação:** Zod para todos os formulários e inputs de API.
