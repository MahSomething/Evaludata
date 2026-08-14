# BACKLOG.md

> Product Backlog — Sistema de Gestão Documental para Consultorias de Contabilidade
> Metodologia: Kanban com entregas pequenas e testáveis
> Última atualização: 2026-08-14

---

## Legenda

| Campo | Significado |
|-------|-------------|
| **ID** | Código único da tarefa (ex: `DB-001`) |
| **Tipo** | `DB` (Base de Dados), `BE` (Backend/Server), `FE` (Frontend/UI), `INF` (Infra/DevOps), `QA` (Testes/Qualidade) |
| **Estimativa** | `XS` (1-2h), `S` (2-4h), `M` (4-8h), `L` (1-2 dias), `XL` (2-3 dias) |
| **Depende de** | IDs das tarefas que precisam estar DONE antes desta começar |
| **Responsável** | `Backend` (Server Actions, DB), `Frontend` (UI/UX), `DevOps` (Infra/Config), `QA` (Testes) |
| **Estado** | `Backlog` → `Em Desenvolvimento` → `Code Review` → `QA` → `DONE` |

---

## Épico 1: Fundação da Base de Dados

> **Objetivo:** Schema SQL completo, testado localmente, com RLS, índices e seed data. Sem UI.

---

### Tarefa DB-001 — Criar tabela `organizacoes`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | — |

**Descrição:**
Criar migration `001_organizacoes.sql` com a tabela `organizacoes` (id, nome, nif, owner_id, pode_registar_clientes, ativa, criada_em).

**Critérios de Aceitação:**
- [ ] Migration executa sem erros em `supabase db reset`
- [ ] Colunas têm tipos corretos e constraints (NOT NULL onde aplicável)
- [ ] Índice em `nif` (UNIQUE)
- [ ] Tabela aparece no Supabase Studio local

**Entregável:**
`supabase/migrations/001_organizacoes.sql`

---

### Tarefa DB-002 — Criar tabela `utilizadores`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-001 |

**Descrição:**
Criar migration `002_utilizadores.sql` com a tabela `utilizadores` (id, organizacao_id, email, nome, papel, telemovel, ativo, criado_por, criado_em).

**Critérios de Aceitação:**
- [ ] FK para `organizacoes.id` (ON DELETE CASCADE quando aplicável)
- [ ] CHECK constraint em `papel` ('super_admin', 'admin', 'contabilista', 'cliente')
- [ ] UNIQUE em `email`
- [ ] UNIQUE em `telemovel` (apenas para clientes, mas por enquanto UNIQUE global)

**Entregável:**
`supabase/migrations/002_utilizadores.sql`

---

### Tarefa DB-003 — Criar tabela `empresas`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-001, DB-002 |

**Descrição:**
Criar migration `003_empresas.sql` com a tabela `empresas` (id, organizacao_id, nome, nif, contacto, criado_por, criado_em).

**Critérios de Aceitação:**
- [ ] FK para `organizacoes.id`
- [ ] Índice em `organizacao_id`
- [ ] UNIQUE em `nif` por organização (ou global? decidir)

**Entregável:**
`supabase/migrations/003_empresas.sql`

---

### Tarefa DB-004 — Criar tabelas de ligação `contabilista_empresas` e `cliente_empresas`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-002, DB-003 |

**Descrição:**
Criar migrations `004_contabilista_empresas.sql` e `005_cliente_empresas.sql`.

**Critérios de Aceitação:**
- [ ] FKs corretas para `utilizadores.id` e `empresas.id`
- [ ] UNIQUE constraint em `(contabilista_id, empresa_id)` e `(cliente_id, empresa_id)`
- [ ] Índices em ambas as colunas FK para queries rápidas
- [ ] `atribuido_por` e `atribuido_em` preenchidos

**Entregável:**
`supabase/migrations/004_contabilista_empresas.sql`
`supabase/migrations/005_cliente_empresas.sql`

---

### Tarefa DB-005 — Criar tabela `documentos`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-001, DB-003 |

**Descrição:**
Criar migration `006_documentos.sql` com a tabela `documentos` completa, incluindo campos de versionamento e estados.

**Critérios de Aceitação:**
- [ ] CHECK constraint em `estado` ('ativo', 'pendente', 'rejeitado', 'arquivado', 'eliminado')
- [ ] FK para `empresas.id`
- [ ] FK para `organizacoes.id` (denormalizado para RLS rápido)
- [ ] Índice em `empresa_id + estado + ano`
- [ ] Índice em `data_soft_delete` (para o job de cleanup)
- [ ] `substitui_id` é self-referencing FK (nullable)
- [ ] `documento_pai_id` é self-referencing FK (nullable)

**Entregável:**
`supabase/migrations/006_documentos.sql`

---

### Tarefa DB-006 — Criar tabela `log_acessos`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-002, DB-005 |

**Descrição:**
Criar migration `007_log_acessos.sql` com a tabela `log_acessos`.

**Critérios de Aceitação:**
- [ ] FK para `documentos.id` (ON DELETE CASCADE)
- [ ] FK para `utilizadores.id`
- [ ] CHECK constraint em `acao` ('visualizou', 'transferiu', 'aprovou', 'rejeitou')
- [ ] Índice em `documento_id + criado_em`
- [ ] Índice em `utilizador_id + criado_em`

**Entregável:**
`supabase/migrations/007_log_acessos.sql`

---

### Tarefa DB-007 — Criar tabela `otp_codes`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-002 |

**Descrição:**
Criar migration `008_otp_codes.sql` com a tabela `otp_codes` para autenticação do cliente.

**Critérios de Aceitação:**
- [ ] FK para `utilizadores.id`
- [ ] Índice em `telemovel + codigo + expira_em`
- [ ] Índice em `expira_em` (para cleanup de OTPs antigos)
- [ ] Default `tentativas = 0`, `utilizado = false`

**Entregável:**
`supabase/migrations/008_otp_codes.sql`

---

### Tarefa DB-008 — Implementar RLS com Custom Claims (Parte 1: `organizacoes` e `utilizadores`)

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-001, DB-002 |

**Descrição:**
Ativar RLS nas tabelas `organizacoes` e `utilizadores`. Criar policies usando `auth.jwt() ->> 'organizacao_id'` e `auth.jwt() ->> 'papel'` em vez de subqueries.

**Critérios de Aceitação:**
- [ ] RLS ativado em ambas as tabelas
- [ ] Policies SELECT, INSERT, UPDATE para `organizacoes`
- [ ] Policies SELECT, INSERT, UPDATE para `utilizadores`
- [ ] Super Admin consegue ver tudo
- [ ] Admin só vê utilizadores da sua org
- [ ] Contabilista só se vê a si mesmo
- [ ] Testar com queries diretas no SQL Editor (simulando cada role)

**Entregável:**
Policies SQL em `supabase/migrations/009_rls_organizacoes_utilizadores.sql`

---

### Tarefa DB-009 — Implementar RLS com Custom Claims (Parte 2: `empresas`, `contabilista_empresas`, `cliente_empresas`)

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-003, DB-004, DB-008 |

**Descrição:**
RLS para tabelas de empresas e ligações. Admin vê tudo da sua org. Contabilista vê apenas empresas atribuídas. Cliente vê apenas empresas atribuídas.

**Critérios de Aceitação:**
- [ ] RLS ativado nas 3 tabelas
- [ ] Contabilista não vê empresas não atribuídas
- [ ] Cliente não vê empresas não atribuídas
- [ ] Admin vê todas as empresas da sua org
- [ ] Testar com queries diretas

**Entregável:**
`supabase/migrations/010_rls_empresas_ligacoes.sql`

---

### Tarefa DB-010 — Implementar RLS com Custom Claims (Parte 3: `documentos` e `log_acessos`)

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | L |
| **Responsável** | Backend |
| **Depende de** | DB-005, DB-006, DB-008 |

**Descrição:**
RLS mais complexa: `documentos` com estados (cliente só vê 'ativo'), `log_acessos` imutável.

**Critérios de Aceitação:**
- [ ] RLS ativado em ambas as tabelas
- [ ] Cliente só vê documentos `estado = 'ativo'`
- [ ] Contabilista vê documentos das empresas atribuídas (todos os estados exceto 'eliminado')
- [ ] Admin vê tudo da sua org
- [ ] `log_acessos` não permite UPDATE nem DELETE
- [ ] `log_acessos` INSERT apenas via trigger ou service role
- [ ] Testar com queries diretas para cada role e estado

**Entregável:**
`supabase/migrations/011_rls_documentos_logs.sql`

---

### Tarefa DB-011 — Criar função/trigger para injetar Custom Claims no JWT

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-002 |

**Descrição:**
Criar uma função PostgreSQL que o Supabase Auth chama no login para injetar `organizacao_id` e `papel` no JWT do utilizador.

**Critérios de Aceitação:**
- [ ] Função `public.custom_access_token_hook(event jsonb)` criada
- [ ] Inclui `organizacao_id`, `papel`, `nome` no JWT
- [ ] Configurada no Supabase Dashboard → Auth → Hooks
- [ ] Testar: fazer login e verificar que o JWT contém as claims
- [ ] Documentar no `SUPABASE-SETUP.md`

**Entregável:**
`supabase/migrations/012_custom_claims_hook.sql` + configuração manual no dashboard

---

### Tarefa DB-012 — Criar seed data (Super Admin + tipos de documento)

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-001, DB-002 |

**Descrição:**
Criar `supabase/seed.sql` com Super Admin inicial e tipos de documento padrão.

**Critérios de Aceitação:**
- [ ] `supabase db reset` cria o Super Admin automaticamente
- [ ] Consegue fazer login com o Super Admin (email + password)
- [ ] Tipos de documento aparecem na tabela `tipos_documento`
- [ ] Seed não falha se executado múltiplas vezes (idempotente)

**Entregável:**
`supabase/seed.sql`

---

### Tarefa DB-013 — Criar índice de Full-Text Search em `documentos`

| Campo | Valor |
|-------|-------|
| **Tipo** | DB |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-005 |

**Descrição:**
Criar índice GIN para pesquisa full-text em `notas`, `ficheiro_nome`, `tipo_documento`.

**Critérios de Aceitação:**
- [ ] Índice `idx_documentos_fts` criado
- [ ] Query `SELECT * FROM documentos WHERE to_tsvector(...) @@ to_tsquery(...)` retorna resultados em <100ms
- [ ] Funciona com texto em português

**Entregável:**
`supabase/migrations/013_fulltext_index.sql`

---

### Tarefa QA-001 — Testar schema completo localmente

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | DB-001 a DB-013 |

**Descrição:**
Executar `supabase db reset`, verificar que todas as tabelas, FKs, índices e RLS estão funcionais. Criar script de teste SQL.

**Critérios de Aceitação:**
- [ ] `supabase db reset` executa sem erros
- [ ] Todas as tabelas aparecem no Studio
- [ ] FKs funcionam (tentar inserir com ID inválido → erro)
- [ ] RLS funciona (query como anon → 0 rows; query como Super Admin → todas as rows)
- [ ] Seed data presente

**Entregável:**
`tests/db/schema_validation.sql`

---

## Épico 2: Setup do Projeto Next.js 16

> **Objetivo:** Esqueleto do projeto funcional, com hot reload, tipos gerados e convenções aplicadas.

---

### Tarefa INF-001 — Inicializar projeto Next.js 16 com shadcn/ui

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps / Frontend |
| **Depende de** | — |

**Descrição:**
`npx shadcn@latest init` com Next.js 16, Tailwind v4, TypeScript, App Router.

**Critérios de Aceitação:**
- [ ] `npm run dev` inicia sem erros em `localhost:3000`
- [ ] Tailwind v4 funciona (`@theme` em `globals.css`)
- [ ] shadcn/ui base instalado
- [ ] Nenhum `tailwind.config.js` criado
- [ ] `.gitignore` configurado

**Entregável:**
Repositório Git inicializado, primeira commit.

---

### Tarefa INF-002 — Instalar e configurar Supabase SSR

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | INF-001 |

**Descrição:**
Instalar `@supabase/ssr`, criar os 3 clientes (browser, server, proxy).

**Critérios de Aceitação:**
- [ ] `lib/supabase/client.ts` — `createBrowserClient`
- [ ] `lib/supabase/server.ts` — `createServerClient` com `cookies()`
- [ ] `lib/supabase/proxy.ts` — middleware renomeado (não `middleware.ts`)
- [ ] Variáveis `.env.local` configuradas (URL + anon key)
- [ ] Nenhum erro de tipo no TypeScript

**Entregável:**
`lib/supabase/*` + `.env.local` (template)

---

### Tarefa INF-003 — Configurar Supabase CLI no projeto

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps |
| **Depende de** | INF-001 |

**Descrição:**
`supabase init`, linkar projeto, criar pasta `supabase/migrations/`.

**Critérios de Aceitação:**
- [ ] `supabase status` mostra serviços a correr
- [ ] `supabase db reset` funciona (ainda que vazio)
- [ ] `package.json` tem scripts: `db:types`, `db:push`, `db:reset`

**Entregável:**
`supabase/config.toml` + scripts no `package.json`

---

### Tarefa INF-004 — Gerar tipos TypeScript do Supabase

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | XS |
| **Responsável** | Backend |
| **Depende de** | INF-003, DB-001 a DB-013 |

**Descrição:**
Gerar `types/database.ts` a partir do schema.

**Critérios de Aceitação:**
- [ ] `npm run db:types` gera o ficheiro sem erros
- [ ] Tipos estão atualizados com todas as tabelas
- [ ] Import `Database` funciona em qualquer ficheiro

**Entregável:**
`types/database.ts`

---

### Tareqa INF-005 — Configurar Zod e React Hook Form

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | XS |
| **Responsável** | Frontend |
| **Depende de** | INF-001 |

**Descrição:**
Instalar `zod`, `react-hook-form`, `@hookform/resolvers`.

**Critérios de Aceitação:**
- [ ] `npm install` completo
- [ ] Exemplo mínimo de formulário com Zod + RHF funciona
- [ ] Sem erros de build

**Entregável:**
`package.json` atualizado + exemplo em `components/forms/exemplo.tsx`

---

## Épico 3: Autenticação Interna (Admin/Contabilista)

> **Objetivo:** Login funcional para Admin e Contabilista com email/senha, Custom Claims, e redirecionamento por role.

---

### Tarefa BE-001 — Server Action: login com email/senha

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | INF-002, DB-011 |

**Descrição:**
Criar Server Action `login` que autentica via Supabase Auth, valida o papel e redireciona.

**Critérios de Aceitação:**
- [ ] Login com credenciais válidas retorna sucesso + cookies
- [ ] Login com credenciais inválidas retorna erro claro
- [ ] Após login, `auth.jwt()` contém `organizacao_id` e `papel`
- [ ] Rate limiting: máx 5 tentativas / 15 min / IP

**Entregável:**
`app/actions/auth.ts` → função `login()`

---

### Tarefa BE-002 — Server Action: logout

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | XS |
| **Responsável** | Backend |
| **Depende de** | BE-001 |

**Descrição:**
Server Action `logout` que limpa cookies e sessão.

**Critérios de Aceitação:**
- [ ] Logout limpa todos os cookies de sessão
- [ ] Após logout, qualquer página protegida redireciona para login
- [ ] Sem erros no servidor

**Entregável:**
`app/actions/auth.ts` → função `logout()`

---

### Tarefa FE-001 — Página de login (/login)

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-001, INF-005 |

**Descrição:**
Página de login com formulário (email + password), validação Zod, erro visual, loading state.

**Critérios de Aceitação:**
- [ ] UI responsiva (mobile + desktop)
- [ ] Validação em tempo real (email válido, password não vazia)
- [ ] Estado de loading no botão
- [ ] Mensagem de erro clara (credenciais inválidas, conta inativa)
- [ ] Redireciona para `/dashboard` após login bem-sucedido
- [ ] Não acessível se já autenticado (redirect para dashboard)

**Entregável:**
`app/(auth)/login/page.tsx` + `components/forms/login-form.tsx`

---

### Tarefa FE-002 — Layout protegido do Dashboard

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | FE-001 |

**Descrição:**
Layout com sidebar/nav para o dashboard. Verifica autenticação no server e redireciona se não autenticado.

**Critérios de Aceitação:**
- [ ] Sidebar com navegação (Empresas, Documentos, Utilizadores, Aprovações)
- [ ] Mostra nome do utilizador logado
- [ ] Botão de logout funcional
- [ ] Não autenticado → redirect para /login
- [ ] Cliente autenticado → redirect para /portal

**Entregável:**
`app/(dashboard)/layout.tsx` + `components/layout/sidebar.tsx`

---

### Tarefa BE-003 — Server Action: criar utilizador (Admin/Contabilista)

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-002, BE-001 |

**Descrição:**
Server Action para Admin criar contabilistas. Super Admin criar Admins. Valida permissões.

**Critérios de Aceitação:**
- [ ] Admin só cria contabilistas da sua org
- [ ] Super Admin cria Admins de qualquer org
- [ ] Email único validado
- [ ] Password temporária gerada e enviada (ou definida pelo criador)
- [ ] Custom Claims injetadas automaticamente
- [ ] Log de criação

**Entregável:**
`app/actions/utilizadores.ts` → função `criarUtilizador()`

---

### Tarefa QA-002 — Testar fluxo de login completo

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | S |
| **Responsável** | QA |
| **Depende de** | FE-001, FE-002, BE-001, BE-002 |

**Descrição:**
Testar manualmente todo o fluxo: login → dashboard → logout → tentativa de acesso sem auth.

**Critérios de Aceitação:**
- [ ] Login com Super Admin funciona
- [ ] Login com Admin funciona
- [ ] Login com credenciais erradas mostra erro
- [ ] Logout funciona e limpa sessão
- [ ] Aceder `/dashboard` sem login → redirect para `/login`
- [ ] Aceder `/login` com sessão ativa → redirect para `/dashboard`

**Entregável:**
Relatório de teste (checklist acima preenchida)

---

## Épico 4: Gestão de Empresas

> **Objetivo:** CRUD completo de empresas (clientes da contabilidade), com atribuição a contabilistas.

---

### Tarefa BE-004 — Server Actions: CRUD empresas

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-003, BE-001 |

**Descrição:**
Server Actions para criar, listar, editar e (soft) eliminar empresas. RLS garante isolamento.

**Critérios de Aceitação:**
- [ ] `criarEmpresa` — valida NIF, nome, cria com `organizacao_id` do admin
- [ ] `listarEmpresas` — retorna apenas empresas da org (RLS já filtra, mas validar)
- [ ] `atualizarEmpresa` — apenas campos permitidos
- [ ] `eliminarEmpresa` — soft delete (marca `ativo = false` ou cria estado)
- [ ] Todas as actions retornam `{ success, error, data }`

**Entregável:**
`app/actions/empresas.ts`

---

### Tarefa FE-003 — Página: Lista de Empresas

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-004, FE-002 |

**Descrição:**
Tabela de empresas com filtros (nome, NIF), paginação, botão "Nova Empresa".

**Critérios de Aceitação:**
- [ ] Tabela mostra nome, NIF, contacto, número de documentos
- [ ] Filtro por nome funciona (debounce 300ms)
- [ ] Filtro por NIF funciona
- [ ] Paginação (10 por página)
- [ ] Botão "Nova Empresa" abre modal/drawer
- [ ] Loading state enquanto carrega
- [ ] Empty state se não houver empresas

**Entregável:**
`app/(dashboard)/empresas/page.tsx` + `components/tables/empresas-table.tsx`

---

### Tarefa FE-004 — Componente: Modal de Criar/Editar Empresa

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | S |
| **Responsável** | Frontend |
| **Depende de** | FE-003, INF-005 |

**Descrição:**
Modal/drawer com formulário Zod para criar ou editar empresa.

**Critérios de Aceitação:**
- [ ] Campos: nome, NIF (validação de 9 dígitos), contacto (opcional)
- [ ] Validação Zod em tempo real
- [ ] Submit chama Server Action
- [ ] Sucesso: fecha modal, atualiza tabela (revalidate ou optimistic)
- [ ] Erro: mostra mensagem no modal
- [ ] Modo edição pré-preenche campos

**Entregável:**
`components/forms/empresa-form.tsx` + `components/modals/empresa-modal.tsx`

---

### Tarefa BE-005 — Server Action: atribuir empresa a contabilista

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-004, BE-004 |

**Descrição:**
Server Action para Admin atribuir/desatribuir empresas a contabilistas.

**Critérios de Aceitação:**
- [ ] `atribuirEmpresa(contabilistaId, empresaId)`
- [ ] `removerAtribuicao(contabilistaId, empresaId)`
- [ ] Valida que ambos pertencem à mesma org
- [ ] Não permite duplicados (UNIQUE constraint)
- [ ] Retorna lista atualizada de atribuições

**Entregável:**
`app/actions/atribuicoes.ts`

---

### Tarefa FE-005 — Componente: Atribuição de Empresas a Contabilista

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-005, FE-003 |

**Descrição:**
Na página do contabilista (ou num modal), interface para selecionar/deselecionar empresas.

**Critérios de Aceitação:**
- [ ] Lista de empresas da consultoria com checkboxes
- [ ] Empresas atribuídas vêm pré-selecionadas
- [ ] Guardar atualiza as atribuições em batch
- [ ] Loading state durante o save
- [ ] Sucesso: toast de confirmação

**Entregável:**
`components/forms/atribuicao-empresas.tsx`

---

### Tarefa QA-003 — Testar CRUD de empresas e atribuições

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | FE-003, FE-004, FE-005, BE-004, BE-005 |

**Descrição:**
Testar manualmente: criar empresa, editar, eliminar, atribuir a contabilista, verificar que contabilista só vê as atribuídas.

**Critérios de Aceitação:**
- [ ] Criar empresa com NIF válido → sucesso
- [ ] Criar empresa com NIF inválido → erro de validação
- [ ] Editar empresa → reflete na lista
- [ ] Atribuir empresa A a contabilista X → X vê A no dashboard
- [ ] Contabilista Y não vê A
- [ ] Eliminar empresa → desaparece da lista (soft delete)

**Entregável:**
Relatório de teste

---

## Épico 5: Upload de Documentos (R2)

> **Objetivo:** Upload de PDF/imagem para R2 via Signed URLs, registo na BD, validação de ficheiros.

---

### Tarefa INF-006 — Configurar cliente S3 para R2

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps |
| **Depende de** | INF-001 |

**Descrição:**
Instalar `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`, criar `lib/storage/r2.ts`.

**Critérios de Aceitação:**
- [ ] Cliente S3 configurado com endpoint do R2
- [ ] Função `getUploadSignedUrl` gera URL válida
- [ ] Função `getDownloadSignedUrl` gera URL válida
- [ ] Função `deleteFile` elimina ficheiro do bucket
- [ ] Testar com ficheiro real no R2 (bucket de teste)

**Entregável:**
`lib/storage/r2.ts`

---

### Tarefa BE-006 — Server Action: gerar signed URL para upload

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | INF-006, DB-005, BE-001 |

**Descrição:**
Server Action `requestUploadUrl` que valida permissões, cria registo em `documentos`, gera signed URL do R2.

**Critérios de Aceitação:**
- [ ] Valida que contabilista tem acesso à empresa
- [ ] Valida tipo de ficheiro (PDF, JPG, PNG) por magic bytes/content-type
- [ ] Valida tamanho máximo (50MB)
- [ ] Cria registo em `documentos` com `estado = 'ativo'` (ou 'pendente' se for substituição)
- [ ] Gera chave única: `orgId/empresaId/docId.ext`
- [ ] Retorna `{ signedUrl, documentoId, fileKey }`

**Entregável:**
`app/actions/storage.ts` → `requestUploadUrl()`

---

### Tarefa BE-007 — Server Action: confirmar upload e atualizar registo

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | BE-006 |

**Descrição:**
Server Action chamada pelo cliente após upload bem-sucedido para R2. Atualiza `ficheiro_url` e valida.

**Critérios de Aceitação:**
- [ ] Recebe `documentoId` e `fileKey`
- [ ] Atualiza `documentos.ficheiro_url` com URL pública do R2
- [ ] Verifica se o ficheiro realmente existe no R2 (HEAD request)
- [ ] Retorna sucesso/erro

**Entregável:**
`app/actions/storage.ts` → `confirmarUpload()`

---

### Tarefa FE-006 — Componente: Formulário de Upload de Documento

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-006, BE-007, FE-003 |

**Descrição:**
Formulário para upload: selecionar empresa (dropdown), tipo de documento, ano, período, ficheiro.

**Critérios de Aceitação:**
- [ ] Dropdown de empresas (apenas atribuídas ao contabilista)
- [ ] Dropdown de tipos de documento (da tabela `tipos_documento`)
- [ ] Input de ano (number, 2000-2100)
- [ ] Input de período (opcional, texto livre)
- [ ] Input de ficheiro (accept .pdf,.jpg,.png)
- [ ] Preview do ficheiro selecionado (nome, tamanho)
- [ ] Progresso de upload (barra ou percentagem)
- [ ] Sucesso: toast + limpa formulário
- [ ] Erro: mensagem clara (tamanho, tipo, permissão)

**Entregável:**
`components/forms/upload-documento.tsx`

---

### Tarefa BE-008 — Server Action: listar documentos por empresa

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-005, BE-001 |

**Descrição:**
Server Action para listar documentos de uma empresa, com filtros e paginação.

**Critérios de Aceitação:**
- [ ] Filtros: tipo, ano, período, estado
- [ ] Paginação (20 por página)
- [ ] Ordenação por `criado_em DESC`
- [ ] RLS garante que só vê documentos permitidos
- [ ] Retorna dados completos + contagem total

**Entregável:**
`app/actions/documentos.ts` → `listarDocumentos()`

---

### Tarefa FE-007 — Página: Documentos da Empresa

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-008, FE-006 |

**Descrição:**
Página que mostra documentos de uma empresa, agrupados por ano, com filtros e upload.

**Critérios de Aceitação:**
- [ ] Agrupamento visual por ano (accordion ou tabs)
- [ ] Filtros: tipo, período, estado
- [ ] Cada documento mostra: nome, tipo, tamanho, data, estado (badge colorido)
- [ ] Botão de download (chama Server Action de signed URL)
- [ ] Botão "Carregar documento" abre o formulário FE-006
- [ ] Loading state inicial
- [ ] Empty state se não houver documentos

**Entregável:**
`app/(dashboard)/empresas/[id]/documentos/page.tsx`

---

### Tarefa QA-004 — Testar upload e download de documentos

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | FE-006, FE-007, BE-006, BE-007, BE-008 |

**Descrição:**
Testar fluxo completo: selecionar empresa → upload PDF → aparece na lista → download → verificar ficheiro.

**Critérios de Aceitação:**
- [ ] Upload de PDF 5MB → sucesso, aparece na lista
- [ ] Upload de JPG → sucesso
- [ ] Upload de ficheiro .exe renomeado para .pdf → erro de validação
- [ ] Upload de ficheiro 100MB → erro de tamanho
- [ ] Download funciona e o ficheiro é idêntico ao original
- [ ] Contabilista B não vê documentos da Empresa A (não atribuída)

**Entregável:**
Relatório de teste + ficheiros de teste usados

---

## Épico 6: Fluxo de Aprovação de Documentos

> **Objetivo:** Substituição de documentos com aprovação do Admin. Estados: ativo, pendente, rejeitado, arquivado.

---

### Tarefa BE-009 — Server Action: submeter nova versão de documento

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | BE-006, DB-005 |

**Descrição:**
Quando contabilista faz upload de documento que substitui outro, criar registo com `estado = 'pendente'` e `substitui_id`.

**Critérios de Aceitação:**
- [ ] Detecta se já existe documento ativo do mesmo tipo/ano/período para a mesma empresa
- [ ] Se sim: novo documento fica `pendente`, `substitui_id` aponta para o ativo
- [ ] Se não: novo documento fica `ativo`
- [ ] Notifica admin (badge na UI — via Realtime ou simples contagem)

**Entregável:**
`app/actions/documentos.ts` → `submeterNovaVersao()`

---

### Tarefa BE-010 — Server Action: aprovar ou rejeitar documento pendente

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | BE-009 |

**Descrição:**
Admin aprova ou rejeita documento pendente. Atualiza estados e regista log.

**Critérios de Aceitação:**
- [ ] `aprovarDocumento(docId)`:
  - Novo doc: `ativo`
  - Doc antigo (substitui_id): `arquivado`
  - Log: "aprovou substituição"
- [ ] `rejeitarDocumento(docId, motivo?)`:
  - Novo doc: `rejeitado`, `data_soft_delete = NOW()`
  - Doc antigo: mantém `ativo`
  - Log: "rejeitou substituição"
- [ ] Apenas Admin pode executar
- [ ] Documento já não pendente → erro

**Entregável:**
`app/actions/documentos.ts` → `aprovarDocumento()`, `rejeitarDocumento()`

---

### Tarefa FE-008 — Página: Aprovações Pendentes

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-010, FE-002 |

**Descrição:**
Página do Admin com lista de documentos pendentes de aprovação. Pode aprovar/rejeitar com preview.

**Critérios de Aceitação:**
- [ ] Lista de pendentes com: empresa, tipo, ano, contabilista que submeteu, data
- [ ] Botão "Aprovar" com confirmação (modal)
- [ ] Botão "Rejeitar" com campo opcional de motivo
- [ ] Preview do documento (iframe ou link para abrir)
- [ ] Comparação lado-a-lado com versão atual (nice-to-have, não obrigatório)
- [ ] Após ação, documento desaparece da lista de pendentes
- [ ] Badge no sidebar mostra contagem de pendentes

**Entregável:**
`app/(dashboard)/aprovacoes/page.tsx`

---

### Tarefa FE-009 — Componente: Badge de Notificações (Realtime)

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | S |
| **Responsável** | Frontend |
| **Depende de** | FE-008 |

**Descrição:**
Badge no sidebar que mostra número de documentos pendentes. Atualiza em tempo real (Supabase Realtime).

**Critérios de Aceitação:**
- [ ] Badge mostra contagem de `documentos WHERE estado = 'pendente'`
- [ ] Atualiza quando um novo documento pendente é criado
- [ ] Desaparece quando não há pendentes
- [ ] Sem necessidade de refresh da página

**Entregável:**
`components/layout/notificacoes-badge.tsx`

---

### Tarefa QA-005 — Testar fluxo de aprovação completo

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | FE-008, FE-009, BE-009, BE-010 |

**Descrição:**
Testar: contabilista faz upload de substituição → aparece em pendentes → admin aprova → nova versão fica ativa → antiga fica arquivada.

**Critérios de Aceitação:**
- [ ] Upload de substituição → estado 'pendente'
- [ ] Aparece na página de aprovações
- [ ] Admin aprova → novo 'ativo', antigo 'arquivado'
- [ ] Cliente vê apenas a versão ativa
- [ ] Admin rejeita → novo 'rejeitado', antigo mantém 'ativo'
- [ ] Badge atualiza corretamente

**Entregável:**
Relatório de teste

---

## Épico 7: Portal do Cliente (OTP WhatsApp)

> **Objetivo:** Cliente acede via número de telemóvel + OTP enviado por WhatsApp. Apenas visualiza documentos ativos.

---

### Tarefa INF-007 — Configurar API WhatsApp (Evolution)

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | M |
| **Responsável** | DevOps |
| **Depende de** | — |

**Descrição:**
Configurar conta Evolution API (ou alternativa), conectar número de telemóvel, testar envio de mensagem.

**Critérios de Aceitação:**
- [ ] Conta criada e número verificado
- [ ] Consegue enviar mensagem de teste via API
- [ ] Variáveis `WHATSAPP_API_URL`, `WHATSAPP_API_KEY`, `WHATSAPP_INSTANCE` no `.env.local`
- [ ] Documentação da API acessível

**Entregável:**
Configuração documentada + teste de envio bem-sucedido

---

### Tarefa BE-011 — Função: enviar OTP via WhatsApp

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | INF-007 |

**Descrição:**
Função `sendOtpWhatsApp(phone, code)` que chama a API Evolution.

**Critérios de Aceitação:**
- [ ] Envia mensagem com código de 6 dígitos
- [ ] Mensagem em português, clara e profissional
- [ ] Retorna true/false (sucesso/erro)
- [ ] Timeout de 10 segundos
- [ ] Log de envio (sucesso/erro)

**Entregável:**
`lib/whatsapp/evolution.ts`

---

### Tarefa BE-012 — Server Action: pedir OTP

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-007, BE-011 |

**Descrição:**
Server Action `requestOtp` que valida telemóvel, gera código, guarda na BD, envia por WhatsApp.

**Critérios de Aceitação:**
- [ ] Valida formato do telemóvel (3519XXXXXXXX)
- [ ] Verifica se telemóvel pertence a cliente ativo
- [ ] Gera código aleatório de 6 dígitos
- [ ] Guarda em `otp_codes` com expiração de 10 min
- [ ] Envia via WhatsApp
- [ ] Rate limiting: 5 pedidos / 15 min / IP
- [ ] Não revela se o número existe (segurança)

**Entregável:**
`app/actions/auth-cliente.ts` → `requestOtp()`

---

### Tarefa BE-013 — Server Action: validar OTP e criar sessão

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | L |
| **Responsável** | Backend |
| **Depende de** | BE-012 |

**Descrição:**
Validar código OTP, criar sessão do cliente (JWT custom ou Supabase Auth), redirecionar para portal.

**Critérios de Aceitação:**
- [ ] Verifica código + telemóvel + não expirado + não utilizado
- [ ] Marca como utilizado
- [ ] Cria sessão válida (cookie httpOnly)
- [ ] Sessão contém: userId, organizacaoId, papel = 'cliente'
- [ ] Expira em 8 horas
- [ ] Retorna erro claro se código inválido/expirado
- [ ] Incrementa tentativas, bloqueia após 3 erros

**Entregável:**
`app/actions/auth-cliente.ts` → `verifyOtp()` + `lib/auth/session.ts`

---

### Tarefa FE-010 — Página: Login do Cliente (/portal/login)

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-012, BE-013 |

**Descrição:**
Página de login do cliente em 2 passos: (1) introduzir telemóvel, (2) introduzir código OTP.

**Critérios de Aceitação:**
- [ ] Passo 1: input de telemóvel com máscara (351 912 345 678)
- [ ] Botão "Receber código no WhatsApp"
- [ ] Loading state enquanto envia
- [ ] Passo 2: input de 6 dígitos (campos separados ou único)
- [ ] Contagem decrescente de 10 minutos (tempo restante)
- [ ] Botão "Reenviar código" (com cooldown de 60s)
- [ ] Erro: código inválido, expirado, tentativas esgotadas
- [ ] Sucesso: redirect para `/portal`
- [ ] Design minimalista, mobile-first

**Entregável:**
`app/(portal)/login/page.tsx`

---

### Tarefa FE-011 — Layout e Página do Portal do Cliente

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | FE-010, BE-013 |

**Descrição:**
Página do cliente após login. Seletor de empresas → lista de documentos ativos → download.

**Critérios de Aceitação:**
- [ ] Seletor de empresas (dropdown ou cards) se cliente tiver >1
- [ ] Lista de documentos da empresa selecionada
- [ ] Filtro por tipo e ano (simples)
- [ ] Cada documento: nome, tipo, data, botão download
- [ ] Download chama Server Action de signed URL
- [ ] Sem upload, sem editar, sem remover
- [ ] Botão de logout
- [ ] Mobile-first, simples, rápido

**Entregável:**
`app/(portal)/layout.tsx` + `app/(portal)/page.tsx`

---

### Tarefa BE-014 — Server Action: listar documentos para cliente

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-005, BE-013 |

**Descrição:**
Server Action que retorna documentos `ativo` das empresas atribuídas ao cliente logado.

**Critérios de Aceitação:**
- [ ] Apenas documentos `estado = 'ativo'`
- [ ] Apenas empresas atribuídas ao cliente
- [ ] Filtros: empresaId, tipo, ano
- [ ] RLS já filtra, mas validar no server action
- [ ] Retorna URL pública do R2 (não signed URL — os ficheiros podem ser públicos no R2? decidir)

**Entregável:**
`app/actions/portal.ts` → `listarDocumentosCliente()`

---

### Tarefa QA-006 — Testar portal do cliente completo

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | FE-010, FE-011, BE-012, BE-013, BE-014 |

**Descrição:**
Testar fluxo: cliente introduz telemóvel → recebe OTP no WhatsApp → introduz código → vê empresas → vê documentos → faz download.

**Critérios de Aceitação:**
- [ ] OTP recebido no WhatsApp em <30 segundos
- [ ] Código errado → erro claro
- [ ] Código expirado (>10min) → erro
- [ ] Login bem-sucedido → vê apenas empresas atribuídas
- [ ] Vê apenas documentos 'ativo'
- [ ] Não vê documentos de outras empresas
- [ ] Download funciona
- [ ] Logout funciona
- [ ] Aceder `/portal` sem sessão → redirect para `/portal/login`

**Entregável:**
Relatório de teste

---

## Épico 8: Manutenção e Auditoria

> **Objetivo:** Job de cleanup de 90 dias, log de acessos, painel de auditoria.

---

### Tarefa BE-015 — Edge Function: cleanup de documentos expirados

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | M |
| **Responsável** | Backend |
| **Depende de** | DB-005, INF-006 |

**Descrição:**
Edge Function que corre diariamente, elimina documentos `rejeitado` ou `eliminado` com mais de 90 dias.

**Critérios de Aceitação:**
- [ ] Busca documentos com `data_soft_delete < NOW() - 90 days`
- [ ] Elimina ficheiro do R2 **PRIMEIRO**
- [ ] Só depois elimina registo da BD
- [ ] Log do que foi eliminado
- [ ] Retorna contagem de eliminados
- [ ] Testar em staging com documentos antigos

**Entregável:**
`supabase/functions/cleanup/index.ts`

---

### Tarefa INF-008 — Configurar cron job para cleanup

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps |
| **Depende de** | BE-015 |

**Descrição:**
Configurar invocação diária da Edge Function (pg_cron ou Vercel Cron).

**Critérios de Aceitação:**
- [ ] Corre todos os dias às 3h da manhã
- [ ] Log de execução visível
- [ ] Alerta se falhar (email ou log)
- [ ] Testar execução manual antes de agendar

**Entregável:**
Configuração de cron + documentação

---

### Tarefa BE-016 — Server Action: registar log de acesso

| Campo | Valor |
|-------|-------|
| **Tipo** | BE |
| **Estimativa** | S |
| **Responsável** | Backend |
| **Depende de** | DB-006 |

**Descrição:**
Função reutilizável para registar ações (visualizar, download, aprovar, rejeitar) na tabela `log_acessos`.

**Critérios de Aceitação:**
- [ ] Chamada automaticamente em cada download
- [ ] Chamada em cada aprovação/rejeição
- [ ] Regista IP e user-agent
- [ ] Não bloqueia a operação principal (fire-and-forget ou try/catch)

**Entregável:**
`lib/audit/logger.ts` → `registarLog()`

---

### Tarefa FE-012 — Página: Auditoria (Admin)

| Campo | Valor |
|-------|-------|
| **Tipo** | FE |
| **Estimativa** | M |
| **Responsável** | Frontend |
| **Depende de** | BE-016, FE-002 |

**Descrição:**
Página do Admin para visualizar logs de acesso. Filtros por utilizador, empresa, data, ação.

**Critérios de Aceitação:**
- [ ] Tabela de logs com: data, utilizador, ação, documento, IP
- [ ] Filtros: utilizador, empresa, ação, data range
- [ ] Paginação
- [ ] Apenas Admin e Super Admin acedem
- [ ] Exportar para CSV (nice-to-have)

**Entregável:**
`app/(dashboard)/auditoria/page.tsx`

---

### Tarefa QA-007 — Testar cleanup e auditoria

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | S |
| **Responsável** | QA |
| **Depende de** | BE-015, BE-016, FE-012 |

**Descrição:**
Testar: log de download aparece na auditoria → documento eliminado há 91 dias → job remove ficheiro e registo.

**Critérios de Aceitação:**
- [ ] Download registado em `log_acessos`
- [ ] Aprovação registada em `log_acessos`
- [ ] Documento com `data_soft_delete` há 91 dias → eliminado pelo job
- [ ] Ficheiro não existe mais no R2
- [ ] Registo não existe mais na BD
- [ ] Documento com 89 dias → NÃO eliminado

**Entregável:**
Relatório de teste

---

## Épico 9: Polimento e Deploy

> **Objetivo:** Sistema funcional em produção, documentado, com testes de segurança.

---

### Tarefa INF-009 — Configurar deploy na Vercel

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps |
| **Depende de** | Todos os épicos anteriores |

**Descrição:**
Configurar projeto na Vercel, variáveis de ambiente, domínio custom.

**Critérios de Aceitação:**
- [ ] Build passa sem erros
- [ ] Variáveis de ambiente configuradas no dashboard Vercel
- [ ] Domínio custom configurado
- [ ] Deploy automático a partir da branch `main`
- [ ] Preview deploys para PRs

**Entregável:**
Projeto deployed e acessível

---

### Tarefa QA-008 — Teste de segurança (pentest leve)

| Campo | Valor |
|-------|-------|
| **Tipo** | QA |
| **Estimativa** | M |
| **Responsável** | QA |
| **Depende de** | Todos os épicos anteriores |

**Descrição:**
Testar cenários de segurança críticos.

**Critérios de Aceitação:**
- [ ] Contabilista A não acede a documentos da Empresa B (não atribuída)
- [ ] Cliente X não acede a documentos da Empresa Y
- [ ] Cliente não consegue aceder a `/dashboard`
- [ ] Admin não consegue aceder a dados de outra organização
- [ ] Tentativa de SQL injection nos filtros → sanitizado
- [ ] Tentativa de XSS nos campos de texto → escapado
- [ ] Upload de ficheiro malicioso → bloqueado
- [ ] Brute force login → rate limited

**Entregável:**
Relatório de segurança

---

### Tarefa INF-010 — Documentação final do projeto

| Campo | Valor |
|-------|-------|
| **Tipo** | INF |
| **Estimativa** | S |
| **Responsável** | DevOps / Backend |
| **Depende de** | Todos os épicos anteriores |

**Descrição:**
Atualizar README, documentar como correr localmente, como fazer deploy, como adicionar nova consultoria.

**Critérios de Aceitação:**
- [ ] README com: stack, como correr, variáveis de ambiente
- [ ] Documentação de como criar Super Admin
- [ ] Documentação de como criar nova consultoria
- [ ] Documentação de como configurar WhatsApp API
- [ ] Documentação de como configurar R2

**Entregável:**
`README.md` atualizado

---

## Resumo por Épico

| Épico | Tarefas | Estimativa Total |
|-------|---------|------------------|
| 1. Fundação da BD | DB-001 a DB-013, QA-001 | ~3-4 dias |
| 2. Setup Next.js | INF-001 a INF-005 | ~1 dia |
| 3. Auth Interno | BE-001 a BE-003, FE-001, FE-002, QA-002 | ~2-3 dias |
| 4. Gestão de Empresas | BE-004, BE-005, FE-003 a FE-005, QA-003 | ~2-3 dias |
| 5. Upload R2 | INF-006, BE-006 a BE-008, FE-006, FE-007, QA-004 | ~3 dias |
| 6. Aprovação | BE-009, BE-010, FE-008, FE-009, QA-005 | ~2-3 dias |
| 7. Portal Cliente | INF-007, BE-011 a BE-014, FE-010, FE-011, QA-006 | ~3-4 dias |
| 8. Auditoria | BE-015, BE-016, INF-008, FE-012, QA-007 | ~2 dias |
| 9. Deploy | INF-009, INF-010, QA-008 | ~1-2 dias |
| **TOTAL** | **48 tarefas** | **~19-25 dias** (1 dev full-time) |

---

## Regras de Trabalho

1. **Uma tarefa de cada vez.** Nunca começar Tarefa N sem a Tarefa N-1 estar em `DONE`.
2. **Code Review implícito.** Cada entregável é revisado antes de passar para `QA`.
3. **QA é obrigatório.** Nenhuma tarefa passa para `DONE` sem checklist de aceitação preenchida.
4. **Se uma tarefa revelar um bug em outra já feita:**
   - Criar nova tarefa de bug
   - Priorizar acima do backlog atual
   - Não avançar até o bug estar `DONE`
5. **Documentação viva.** Cada mudança no schema atualiza `types/database.ts`.
