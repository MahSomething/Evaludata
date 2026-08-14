# CONTEXT DUMP — Evaludata
> Resumo completo do estado do projeto para transferencia entre sessoes.
> Gerado: 2026-08-14
> Repositorio: https://github.com/MahSomething/Evaludata

---

## 1. O que e o Evaludata

Sistema de gestao documental multi-tenant para consultorias de contabilidade em Moçambique.

**Problema real resolvido:** Consultorias perdem tempo a procurar documentos fiscais (Comparativos IVA, Relatorios IRS, Extratos Bancarios) espalhados por pastas, emails e drives. O sistema centraliza, organiza por cliente/ano/tipo, e permite ao cliente aceder via portal.

**Nao e:** OCR, extracao automatica de dados, billing entre consultorias, mobile app.

**E:** Upload de PDF/imagem, pesquisa por metadados, versionamento com aprovacao, portal do cliente via OTP WhatsApp, auditoria completa.

---

## 2. Decisoes Arquiteturais Criticas (JA TOMADAS)

| Decisao | Escolha | Porque |
|---------|---------|--------|
| Frontend | Next.js 16 + App Router | Unico router suportado, Server Components por padrao |
| Styling | Tailwind CSS v4 + shadcn/ui | Configuracao via CSS (@theme), nunca tailwind.config.js |
| BD + Auth | Supabase (Postgres + Auth) | Multi-tenant nativo, RLS, realtime |
| Storage | Cloudflare R2 (S3 API) | Egress gratuito, signed URLs, evita custos Supabase |
| Auth interno | Email/senha (Supabase Auth) | Admin e Contabilista |
| Auth cliente | OTP via WhatsApp (Evolution API) | 6 digitos, 10 min expiracao, mais robusto que magic link |
| RLS | Custom Claims no JWT | NUNCA subqueries em policies — performance e seguranca |
| Upload | Signed URLs direto para R2 | NUNCA via Server Action (limite 1MB) |
| Sessao cliente | JWT custom (jose) | Sessao propria, nao depende do Supabase Auth para clientes |
| Cleanup | Edge Function + cron | Documentos rejeitados/eliminados: 90 dias ate remocao fisica |

---

## 3. Stack Fixa (Nao Negociavel)

- Next.js 16.x (App Router, Turbopack)
- React 19.x
- Node.js 22 LTS
- Tailwind CSS v4 (config em globals.css, NUNCA tailwind.config.js)
- shadcn/ui (via CLI: npx shadcn@latest add [componente])
- TypeScript 5.x
- Supabase (Postgres + Auth + @supabase/ssr)
- Cloudflare R2 (@aws-sdk/client-s3, @aws-sdk/s3-request-presigner)
- Zod + React Hook Form + @hookform/resolvers

---

## 4. Modelo de Dados (10 Tabelas)

```
organizacoes          — consultorias (multi-tenant)
  id, nome, nuit, owner_id, pode_registar_clientes, ativa

utilizadores          — todos os que tem login
  id, organizacao_id, email, nome, papel (enum), telemovel, ativo, criado_por

empresas              — clientes da contabilidade
  id, organizacao_id, nome, nuit, contacto, ativa

contabilista_empresas — matriz: quais empresas cada contabilista ve
  id, contabilista_id, empresa_id, atribuido_por

cliente_empresas      — matriz: quais empresas cada cliente ve
  id, cliente_id, empresa_id, atribuido_por

documentos            — documentos fiscais com versionamento
  id, empresa_id, organizacao_id, tipo_documento, ano, periodo,
  ficheiro_url, ficheiro_nome, ficheiro_tamanho,
  versao, documento_pai_id, estado (enum), substitui_id,
  data_soft_delete, metadados (jsonb), notas,
  criado_por, atualizado_por

log_acessos           — auditoria imutavel
  id, documento_id, utilizador_id, acao (enum), ip, user_agent

otp_codes             — codigos temporarios para login cliente
  id, utilizador_id, telemovel, codigo, expira_em, tentativas, utilizado

tipos_documento       — lista configuravel
  id, nome, descricao, ativo
```

**RLS:** Todas as tabelas tem RLS ativado. Policies usam `auth.jwt() ->> 'organizacao_id'` e `auth.jwt() ->> 'papel'` (Custom Claims), NUNCA subqueries.

**Hook:** `public.custom_access_token_hook(event jsonb)` injeta claims no JWT no login.

---

## 5. Hierarquia de Permissoes

```
Super Admin
    └── cria organizacao + designa Owner
        └── Admin (Owner)
            ├── cria empresas
            ├── cria contabilistas
            ├── atribui empresas a contabilistas
            ├── cria clientes (se pode_registar_clientes = true)
            ├── atribui empresas a clientes
            ├── aprova/rejeita documentos pendentes
            └── elimina documentos (soft delete)
                ├── Contabilista
                │   ├── upload de documentos
                │   ├── edita metadados (proprios)
                │   ├── submite nova versao (pendente de aprovacao)
                │   └── NUNCA elimina
                └── Cliente
                    ├── login via OTP WhatsApp
                    ├── visualiza documentos ATIVOS das empresas atribuidas
                    └── NUNCA upload/edit/elimina
```

---

## 6. Fluxos de Negocio Definidos

### 6.1 Upload de Documento
1. Contabilista seleciona empresa + tipo + ano + ficheiro
2. Server Action valida permissao e gera signed URL do R2
3. Cliente faz upload DIRETO para R2 (PUT)
4. Cliente notifica servidor "upload completo"
5. Servidor cria registo em `documentos`
6. Se substitui documento existente: estado = 'pendente', notifica Admin

### 6.2 Aprovacao de Documento
1. Admin ve lista de pendentes
2. Preview do documento (iframe PDF)
3. Aprovar: novo fica 'ativo', antigo fica 'arquivado'
4. Rejeitar: novo fica 'rejeitado', antigo mantem 'ativo', data_soft_delete = NOW()

### 6.3 Login do Cliente (Portal)
1. Introduz numero de telemovel (formato: 351912345678)
2. Servidor gera OTP (6 digitos), guarda em `otp_codes` (expira 10 min)
3. Envia OTP via Evolution API (WhatsApp)
4. Cliente introduz OTP (6 caixas, auto-focus)
5. Servidor valida: codigo + telemovel + nao expirado + nao utilizado + tentativas < 3
6. Cria sessao JWT custom (8h), redireciona para /portal

### 6.4 Cleanup de 90 Dias
1. Edge Function corre diariamente (cron)
2. Busca documentos `rejeitado` ou `eliminado` com data_soft_delete > 90 dias
3. Elimina ficheiro do R2 PRIMEIRO
4. Depois elimina registo da BD
5. Se falhar a meio: reprocessa no proximo ciclo (ficheiros orfaos sao aceitaveis temporariamente)

---

## 7. Documentacao no Repositorio

| Ficheiro | Conteudo |
|----------|----------|
| KIMI.md | Convencoes tecnicas: stack, estrutura de pastas, 3 clientes Supabase, Tailwind v4, RLS com Custom Claims, lista de NAO FAZER |
| MVP-SCOPE.md | O que ENTRA vs O que FICA FORA, criterio de "pronto", stack fixa |
| AUTH-MATRIX.md | Matriz de permissoes por tabela e por role, policies RLS em SQL, fluxos de aprovacao e eliminacao |
| STORAGE-R2.md | Arquitetura R2, fluxo de upload/download via signed URLs, Edge Function de cleanup, estrutura de pastas no bucket |
| AUTH-CLIENTE.md | Fluxo OTP WhatsApp, API Evolution, sessao custom JWT, UI do portal, rate limiting |
| SUPABASE-SETUP.md | Instalacao CLI, migrations, seed, tipos TypeScript, Edge Functions, cron, secrets |
| BACKLOG.md | 48 tarefas em 9 Epicos, estimativas, dependencias, criterios de aceitacao |
| UX-DESIGN.md | Principios de UX, design system, wireframes de 7 ecras, estados vazios/erro/loading, responsividade, acessibilidade |
| SECURITY.md | Classificacao de dados, 10 pontos criticos, 6 nice-to-have, checklist por tarefa, resposta a incidentes, GDPR/OCC |

---

## 8. Estado do Repositorio

**Branch:** main
**Migrations SQL:** 10 (001 a 010)
**Seed:** supabase/seed.sql (tipos de documento + instrucoes Super Admin)
**Commits:** 6

```
6a36ddc docs: documentacao inicial do projeto
00c0639 feat(db): migration 001 — tabela organizacoes
9a64c2d feat(db): migration 002 — tabela utilizadores
bc87d1c feat(db): migration 003 — tabela empresas
ecde175 feat(db): migration 004/005 — tabelas de ligacao
c269bfd feat(db): migration 006 — tabela documentos
00586b7 feat(db): migration 007/008 — log_acessos e otp_codes
d512f37 feat(db): migration 009/010 + seed — custom claims e tipos_documento
34d0be9 chore: renomear CLAUDE.md → KIMI.md
9a8831a docs: SECURITY.md + limpeza de emojis
```

---

## 9. Tarefas Concluidas

**Epico 1: Fundacao da BD (COMPLETO)**
- DB-001 a DB-013: 10 migrations + seed
- DB-011: Custom Claims hook
- DB-012: Seed data

---

## 10. Proximas Tarefas (Backlog)

**Epico 2: Setup Next.js 16**
- INF-001: Inicializar projeto (npx shadcn@latest init)
- INF-002: Configurar Supabase SSR (3 clientes)
- INF-003: Configurar Supabase CLI
- INF-004: Gerar tipos TypeScript
- INF-005: Instalar Zod + React Hook Form

**Epico 3: Auth Interno**
- BE-001: Server Action login email/senha
- BE-002: Server Action logout
- BE-003: Server Action criar utilizador
- FE-001: Pagina /login
- FE-002: Layout protegido dashboard
- QA-002: Testar fluxo login

**Epico 4: Gestao de Empresas**
- BE-004: CRUD empresas
- FE-003: Lista de empresas
- FE-004: Modal criar/editar empresa
- BE-005: Atribuir empresa a contabilista
- FE-005: Componente atribuicao
- QA-003: Testar CRUD empresas

**Epico 5: Upload R2**
- INF-006: Cliente S3 R2
- BE-006: Server Action signed URL upload
- BE-007: Confirmar upload
- FE-006: Formulario upload
- BE-008: Listar documentos
- FE-007: Pagina documentos da empresa
- QA-004: Testar upload/download

**Epico 6: Aprovacao**
- BE-009: Submeter nova versao
- BE-010: Aprovar/rejeitar
- FE-008: Pagina aprovacoes
- FE-009: Badge notificacoes (Realtime)
- QA-005: Testar fluxo aprovacao

**Epico 7: Portal Cliente**
- INF-007: Configurar Evolution API
- BE-011: Enviar OTP WhatsApp
- BE-012: Pedir OTP
- BE-013: Validar OTP + sessao
- FE-010: Login portal (/portal/login)
- FE-011: Pagina portal (/portal)
- BE-014: Listar documentos cliente
- QA-006: Testar portal completo

**Epico 8: Auditoria**
- BE-015: Edge Function cleanup
- INF-008: Cron job
- BE-016: Registar log de acesso
- FE-012: Pagina auditoria
- QA-007: Testar cleanup

**Epico 9: Deploy**
- INF-009: Deploy Vercel
- QA-008: Pentest leve
- INF-010: Documentacao final

---

## 11. Variaveis de Ambiente Necessarias

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# R2 (Cloudflare)
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=
R2_PUBLIC_URL=
R2_ENDPOINT=

# WhatsApp (Evolution API)
WHATSAPP_API_URL=
WHATSAPP_API_KEY=
WHATSAPP_INSTANCE=

# Sessao custom (portal cliente)
SESSION_SECRET=
```

---

## 12. Notas Importantes para Continuidade

1. **Nunca emojis no codigo** — nem em comentarios SQL, nem em logs, nem em mensagens de erro. Profissionalismo absoluto.

2. **RLS e sagrado** — todas as tabelas novas tem RLS ativado. Nunca desativar.

3. **Custom Claims sao obrigatorios** — nunca usar subqueries em policies RLS.

4. **Upload via signed URL** — nunca via Server Action (limite 1MB).

5. **Eliminacao em 2 fases** — ficheiro R2 primeiro, registo BD depois.

6. **Rate limiting** — 5 logins/15min/IP, 3 OTPs/10min/telefone.

7. **Nunca commitar secrets** — .env.local no .gitignore, usar Vercel Secrets.

8. **Migrations versionadas** — nunca editar schema em producao sem migration.

9. **Server Components por padrao** — Client Component apenas para interatividade.

10. **await params em Next.js 16** — params e searchParams sao assincronos.

---

## 13. Contacto / Contexto

- Repositorio: https://github.com/MahSomething/Evaludata
- Stack: Next.js 16 + Supabase + R2 + Tailwind v4 + shadcn/ui
- Publico-alvo: Consultorias de contabilidade em Moçambique
- Multi-tenant: sim, com organization_id em todas as tabelas
- Cliente externo: sim, portal com OTP WhatsApp
- OCR: NAO (fase 2, se necessario)
