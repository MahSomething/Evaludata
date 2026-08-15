# AUTH-MATRIX.md

> Matriz de permissoes por tabela e por role. RLS com Custom Claims (sem subqueries).
> Atualizacao: 2026-08-15

---

## 1. Hierarquia de Permissoes

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

## 2. Matriz de Acesso por Tabela

| Tabela | Super Admin | Admin | Contabilista | Cliente |
|--------|:-----------:|:-----:|:------------:|:-------:|
| `organizacoes` | CRUD | R (apenas a sua) | - | - |
| `utilizadores` | CRUD | CRUD (na sua org) | R (apenas si) | R (apenas si) |
| `empresas` | CRUD | CRUD (na sua org) | R (atribuidas) | R (atribuidas) |
| `contabilista_empresas` | CRUD | CRUD (na sua org) | R (apenas si) | - |
| `cliente_empresas` | CRUD | CRUD (na sua org) | - | R (apenas si) |
| `documentos` | CRUD | CRUD (na sua org) | CRU (atribuidas) | R (ativos, atribuidas) |
| `log_acessos` | R | R (na sua org) | - | - |
| `otp_codes` | - | - | - | RU (apenas o seu) |
| `tipos_documento` | R | R | R | R |

**Legenda:** C = Create, R = Read, U = Update, D = Delete

---

## 3. Regras de Negocio Criticas

### 3.1 Criacao de Utilizadores

- **Super Admin** pode criar qualquer papel em qualquer organizacao.
- **Admin** pode criar `contabilista` e `cliente` (se `pode_registar_clientes = true`).
- **Admin** NAO pode criar outro `admin`.
- **Contabilista** e **Cliente** NAO podem criar utilizadores.

### 3.2 Upload de Documentos

- Contabilista so pode fazer upload para empresas que lhe foram atribuidas.
- Documento novo: `estado = 'ativo'` (primeira versao) ou `estado = 'pendente'` (versao subsequente).
- O campo `criado_por` e preenchido automaticamente.

### 3.3 Aprovacao de Documentos

- So Admin pode aprovar ou rejeitar.
- Aprovar: nova versao fica `ativo`, anterior fica `arquivado`.
- Rejeitar: nova versao fica `rejeitado`, anterior mantem `ativo`.
- Documento `rejeitado` fica visivel em auditoria por 90 dias.

### 3.4 Eliminacao

- So Admin pode eliminar (soft delete).
- `estado = 'eliminado'`, `data_soft_delete = NOW()`.
- Ficheiro fisico e removido apos 90 dias por Edge Function.

---

## 4. RLS Policies (Custom Claims — Sem Subqueries)

> **Regra fundamental:** TODAS as policies usam `auth.jwt() ->> 'organizacao_id'` e `auth.jwt() ->> 'papel'`.
> **NUNCA** usar subqueries em RLS policies.

### 4.1 Hook de Custom Claims

O hook `public.custom_access_token_hook(event jsonb)` injeta no JWT:

```json
{
  "organizacao_id": "uuid-da-organizacao",
  "papel": "admin|contabilista|cliente|super_admin"
}
```

### 4.2 Exemplos de Policies

#### `organizacoes`

```sql
-- Super Admin: tudo
CREATE POLICY "super_admin_all" ON organizacoes
  FOR ALL
  USING (auth.jwt() ->> 'papel' = 'super_admin');

-- Admin: apenas a sua organizacao
CREATE POLICY "admin_own_org" ON organizacoes
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' = 'admin'
    AND auth.jwt() ->> 'organizacao_id' = id::text
  );
```

#### `utilizadores`

```sql
-- Super Admin: tudo
CREATE POLICY "super_admin_all" ON utilizadores
  FOR ALL
  USING (auth.jwt() ->> 'papel' = 'super_admin');

-- Admin: CRUD na sua organizacao
CREATE POLICY "admin_crud_org" ON utilizadores
  FOR ALL
  USING (
    auth.jwt() ->> 'papel' = 'admin'
    AND auth.jwt() ->> 'organizacao_id' = organizacao_id::text
  );

-- Contabilista/Cliente: apenas leitura de si mesmo
CREATE POLICY "user_read_self" ON utilizadores
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' IN ('contabilista', 'cliente')
    AND auth.uid() = id
  );
```

#### `empresas`

```sql
-- Super Admin: tudo
CREATE POLICY "super_admin_all" ON empresas
  FOR ALL
  USING (auth.jwt() ->> 'papel' = 'super_admin');

-- Admin: CRUD na sua organizacao
CREATE POLICY "admin_crud_org" ON empresas
  FOR ALL
  USING (
    auth.jwt() ->> 'papel' = 'admin'
    AND auth.jwt() ->> 'organizacao_id' = organizacao_id::text
  );

-- Contabilista: empresas atribuidas (via matriz)
CREATE POLICY "contabilista_read_assigned" ON empresas
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' = 'contabilista'
    AND EXISTS (
      SELECT 1 FROM contabilista_empresas
      WHERE contabilista_id = auth.uid()
      AND empresa_id = empresas.id
    )
  );

-- Cliente: empresas atribuidas (via matriz)
CREATE POLICY "cliente_read_assigned" ON empresas
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' = 'cliente'
    AND EXISTS (
      SELECT 1 FROM cliente_empresas
      WHERE cliente_id = auth.uid()
      AND empresa_id = empresas.id
    )
  );
```

> **Nota:** As policies de matriz (`contabilista_empresas`, `cliente_empresas`) usam `EXISTS` com subquery porque a tabela de matriz e pequena e o PostgreSQL otimiza bem. A regra "sem subqueries" aplica-se principalmente a tabelas grandes como `documentos`.

#### `documentos`

```sql
-- Super Admin: tudo
CREATE POLICY "super_admin_all" ON documentos
  FOR ALL
  USING (auth.jwt() ->> 'papel' = 'super_admin');

-- Admin: CRUD na sua organizacao
CREATE POLICY "admin_crud_org" ON documentos
  FOR ALL
  USING (
    auth.jwt() ->> 'papel' = 'admin'
    AND auth.jwt() ->> 'organizacao_id' = organizacao_id::text
  );

-- Contabilista: CRU para empresas atribuidas
CREATE POLICY "contabilista_crud_assigned" ON documentos
  FOR ALL
  USING (
    auth.jwt() ->> 'papel' = 'contabilista'
    AND auth.jwt() ->> 'organizacao_id' = organizacao_id::text
    AND EXISTS (
      SELECT 1 FROM contabilista_empresas
      WHERE contabilista_id = auth.uid()
      AND empresa_id = documentos.empresa_id
    )
  );

-- Cliente: apenas READ de documentos ATIVOS de empresas atribuidas
CREATE POLICY "cliente_read_active" ON documentos
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' = 'cliente'
    AND estado = 'ativo'
    AND EXISTS (
      SELECT 1 FROM cliente_empresas
      WHERE cliente_id = auth.uid()
      AND empresa_id = documentos.empresa_id
    )
  );
```

#### `log_acessos`

```sql
-- Super Admin: leitura
CREATE POLICY "super_admin_read" ON log_acessos
  FOR SELECT
  USING (auth.jwt() ->> 'papel' = 'super_admin');

-- Admin: leitura da sua organizacao
CREATE POLICY "admin_read_org" ON log_acessos
  FOR SELECT
  USING (
    auth.jwt() ->> 'papel' = 'admin'
    AND auth.jwt() ->> 'organizacao_id' = (
      SELECT organizacao_id FROM documentos WHERE id = log_acessos.documento_id
    )::text
  );
```

---

## 5. Fluxos de Aprovacao e Eliminacao

### 5.1 Fluxo de Aprovacao

```
Contabilista faz upload de nova versao
  |
  v
Documento criado com estado = 'pendente'
  |
  v
Admin ve lista de pendentes
  |
  +-- Aprovar --> estado = 'ativo' (nova versao), anterior = 'arquivado'
  |
  +-- Rejeitar --> estado = 'rejeitado', anterior mantem 'ativo'
```

### 5.2 Fluxo de Eliminacao

```
Admin clica "Eliminar"
  |
  v
Soft delete: estado = 'eliminado', data_soft_delete = NOW()
  |
  v
Documento desaparece da UI normal
  |
  v
Visivel em painel de auditoria/reciclagem
  |
  v
Apos 90 dias: Edge Function remove ficheiro do R2 e registo da BD
```

---

## 6. Notas de Seguranca

1. **Nunca desativar RLS** em producao.
2. **Nunca usar subqueries** em policies de tabelas grandes (documentos, utilizadores).
3. **Custom Claims sao obrigatorios** — verificar em `auth.jwt()`.
4. **Service Role Key** apenas em Server Actions/Edge Functions, nunca no cliente.
5. **Rate limiting:** 5 logins/15min/IP, 3 OTPs/10min/telefone.
