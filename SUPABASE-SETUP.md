# SUPABASE-SETUP.md

> Guia de configuração do Supabase CLI, migrations versionadas e geração de tipos TypeScript.
> Última atualização: 2026-08-14

---

## 1. Instalação do Supabase CLI

### macOS
```bash
brew install supabase/tap/supabase
```

### Linux
```bash
npm install -g supabase
# ou
npx supabase --version
```

### Windows
```bash
npm install -g supabase
# ou via scoop: scoop install supabase
```

Verificar instalação:
```bash
supabase --version
# Deve mostrar algo como: 2.x.x
```

---

## 2. Login e Link do Projeto

```bash
# Login (abre browser para autenticação)
supabase login

# Linkar com o projeto existente no Supabase Dashboard
# O Project ID está na URL do dashboard: https://supabase.com/dashboard/project/xxxxxxxxxxxx
supabase link --project-id xxxxxxxxxxxx

# Verificar link
supabase status
```

---

## 3. Estrutura de Pastas do Supabase

Criar no root do projeto Next.js:

```
supabase/
 config.toml              # Configuração do projeto local
 migrations/              # Migrations versionadas (SQL)
    20240814120000_initial_schema.sql
    20240814130000_add_otp_codes.sql
    ...
 seed.sql                 # Dados iniciais (Super Admin, tipos de documento)
 functions/               # Edge Functions (TypeScript/Deno)
     cleanup/
         index.ts
```

Inicializar:
```bash
supabase init
# Cria supabase/config.toml e a estrutura base
```

---

## 4. Fluxo de Trabalho com Migrations

### 4.1 Regra de Ouro

**NUNCA** fazer alterações manuais no Supabase Studio (dashboard web) sem gerar migration correspondente.

**Fluxo correto:**
1. Fazer alterações localmente (editar ficheiros em `supabase/migrations/`)
2. Testar localmente com `supabase start` (Docker)
3. Gerar diff se necessário: `supabase db diff`
4. Aplicar em produção: `supabase db push`

### 4.2 Criar uma Nova Migration

```bash
# Método 1: Criar migration vazia e editar manualmente
supabase migration new add_documentos_table
# Cria: supabase/migrations/20240814120000_add_documentos_table.sql

# Método 2: Fazer alterações no studio local e gerar diff
supabase start                    # Inicia stack local (Postgres, Auth, Storage...)
# Fazer alterações no Supabase Studio local (http://localhost:54323)
supabase db diff -f add_nova_coluna   # Gera diff automaticamente
```

### 4.3 Aplicar Migrations em Produção

```bash
# Verificar o que vai ser aplicado
supabase db push --dry-run

# Aplicar
supabase db push

# Forçar (se houver divergências — usar com cuidado!)
supabase db push --include-all
```

### 4.4 Reset Local (para testes)

```bash
# Reset total — elimina tudo e reaplica migrations + seed
supabase db reset

# Apenas reaplica migrations (mantém dados)
supabase stop && supabase start
```

---

## 5. Seed Data

O ficheiro `supabase/seed.sql` é executado automaticamente após `supabase db reset` e `supabase start`.

```sql
-- supabase/seed.sql

-- Super Admin inicial
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'superadmin@tudominio.pt',
  -- Password: 'SuperAdmin123!' (hashed com bcrypt)
  '$2a$10$...hash_aqui...',
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"nome":"Super Admin"}'
);

INSERT INTO public.utilizadores (id, email, nome, papel, ativo, organizacao_id)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'superadmin@tudominio.pt',
  'Super Admin',
  'super_admin',
  true,
  NULL
);

-- Tipos de documento padrão
INSERT INTO public.tipos_documento (nome, descricao) VALUES
  ('Comparativo IVA', 'Comparativo mensal/trimestral de IVA'),
  ('Relatório IRS', 'Relatório de entrega do IRS'),
  ('Extrato Bancário', 'Extrato bancário mensal'),
  ('Declaração IES', 'Declaração anual de IES'),
  ('Recibo Verde', 'Recibo de trabalhador independente'),
  ('Fatura', 'Fatura de despesa/receita'),
  ('Outro', 'Documento não categorizado');
```

**Gerar hash bcrypt:**
```bash
node -e "const bcrypt = require('bcrypt'); console.log(bcrypt.hashSync('SuperAdmin123!', 10));"
```

---

## 6. Gerar Tipos TypeScript

```bash
# Gerar tipos a partir do schema da BD
supabase gen types typescript --project-id xxxxxxxxxxxx > types/database.ts

# Ou a partir do projeto local
supabase gen types typescript --local > types/database.ts
```

**Integrar no package.json:**
```json
{
  "scripts": {
    "db:types": "supabase gen types typescript --project-id xxxxxxxxxxxx > types/database.ts",
    "db:push": "supabase db push",
    "db:reset": "supabase db reset",
    "db:diff": "supabase db diff"
  }
}
```

**Uso no código:**
```ts
import { Database } from "@/types/database";

type Documento = Database["public"]["Tables"]["documentos"]["Row"];
type NovoDocumento = Database["public"]["Tables"]["documentos"]["Insert"];
```

---

## 7. Edge Functions

### 7.1 Criar Edge Function

```bash
supabase functions new cleanup
# Cria: supabase/functions/cleanup/index.ts
```

### 7.2 Deploy

```bash
# Deploy individual
supabase functions deploy cleanup

# Deploy todas
supabase functions deploy

# Ver logs
supabase functions logs cleanup --tail
```

### 7.3 Invocar via HTTP ou Cron

```bash
# Invocar manualmente
curl -X POST https://xxxxxxxxxxxx.supabase.co/functions/v1/cleanup   -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
```

**Configurar cron (pg_cron):**
```sql
-- No Supabase Dashboard → SQL Editor
SELECT cron.schedule(
  'cleanup-documentos',
  '0 3 * * *',  -- Todos os dias às 3h da manhã
  $$ SELECT net.http_post(
    url:='https://xxxxxxxxxxxx.supabase.co/functions/v1/cleanup',
    headers:='{"Authorization": "Bearer SERVICE_ROLE_KEY"}'::jsonb
  ) $$,
  'Europe/Lisbon'
);
```

**Nota:** `pg_cron` pode não estar disponível em todos os planos do Supabase. Alternativa: Vercel Cron Jobs, GitHub Actions, ou serviço externo.

---

## 8. Variáveis de Ambiente no Supabase

### 8.1 Edge Functions

As Edge Functions precisam de variáveis de ambiente específicas:

```bash
# Definir secrets para Edge Functions
supabase secrets set R2_ACCOUNT_ID=xxx
supabase secrets set R2_ACCESS_KEY_ID=xxx
supabase secrets set R2_SECRET_ACCESS_KEY=xxx
supabase secrets set R2_BUCKET_NAME=documentos-consultoria
supabase secrets set R2_ENDPOINT=https://xxx.r2.cloudflarestorage.com
supabase secrets set R2_PUBLIC_URL=https://pub-xxx.r2.dev

# Ver secrets
supabase secrets list
```

### 8.2 Auth Settings (Dashboard)

Configurar no Supabase Dashboard → Authentication → Settings:

- **Site URL:** `https://tudominio.pt`
- **Redirect URLs:** `https://tudominio.pt/**`
- **JWT Expiry:** 3600 (1 hora para admin/contabilista)
- **Disable Signup:** Ativar (utilizadores são criados apenas por Admin/Super Admin)

---

## 9. Checklist de Setup

- [ ] Supabase CLI instalado (`supabase --version`)
- [ ] Projeto linkado (`supabase link --project-id xxx`)
- [ ] `supabase init` executado no root do projeto
- [ ] Pasta `supabase/migrations/` criada
- [ ] Primeira migration (`initial_schema.sql`) com todas as tabelas base
- [ ] `seed.sql` com Super Admin e tipos de documento
- [ ] `supabase db reset` funciona localmente
- [ ] `supabase db push` funciona em produção
- [ ] `npm run db:types` gera `types/database.ts` corretamente
- [ ] Edge Function `cleanup` criada e deployada
- [ ] Secrets do R2 configuradas no Supabase
- [ ] pg_cron configurado (ou alternativa de cron externo)

---

## 10. Comandos Rápidos (Referência)

```bash
# Iniciar stack local
supabase start

# Parar stack local
supabase stop

# Ver status
supabase status

# Criar migration
supabase migration new nome_da_migration

# Gerar diff
supabase db diff -f nome_da_migration

# Aplicar em produção
supabase db push

# Reset local
supabase db reset

# Gerar tipos TypeScript
supabase gen types typescript --local > types/database.ts

# Criar Edge Function
supabase functions new nome

# Deploy Edge Function
supabase functions deploy nome

# Ver logs
supabase functions logs nome --tail

# Gerenciar secrets
supabase secrets set NOME=valor
supabase secrets list
supabase secrets unset NOME
```
