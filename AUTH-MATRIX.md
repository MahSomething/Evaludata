# AUTH-MATRIX.md

> Matriz de permissões e políticas RLS (Row Level Security) por tabela e por role.
> Este documento é a fonte da verdade para quem pode fazer o quê no sistema.
> Última atualização: 2026-08-14

---

## 1. Roles e Hierarquia

```
Super Admin
     Admin (Owner da Consultoria)
             Contabilista
             Cliente
```

**Regra geral:** Um role nunca pode ver/modificar dados de outra `organizacao_id`. Exceção: Super Admin.

---

## 2. Tabela: `organizacoes`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Própria |  Própria |  Própria |
| INSERT |  |  |  |  |
| UPDATE |  (tudo) |  (própria, exceto `pode_registar_clientes`) |  |  |
| DELETE |  |  |  |  |

### RLS Policies (exemplo SQL)

```sql
-- SELECT: Super Admin vê tudo; outros vêem apenas a sua organização
CREATE POLICY "organizacoes_select" ON organizacoes
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
  );

-- INSERT: apenas Super Admin
CREATE POLICY "organizacoes_insert" ON organizacoes
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
  );

-- UPDATE: Super Admin pode tudo; Admin apenas campos permitidos da própria org
CREATE POLICY "organizacoes_update" ON organizacoes
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR (
      id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
    )
  );
```

---

## 3. Tabela: `utilizadores`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org (exceto Super Admin) |  Próprio perfil |  Próprio perfil |
| INSERT |  |  (contabilistas e clientes da sua org, se permitido) |  |  |
| UPDATE |  |  (da sua org, exceto Super Admin) |  (próprio perfil, limitado) |  (próprio perfil, limitado) |
| DELETE |  (soft: ativo=false) |  |  |  |

### Regras Específicas

- **Admin** não pode criar outros Admins nem Super Admins.
- **Admin** só pode criar clientes se `organizacoes.pode_registar_clientes = true`.
- **Contabilista/Cliente** só podem editar: `nome`, `email` (próprio perfil).
- **Super Admin** pode desativar (`ativo = false`) mas não eliminar fisicamente (preservar auditoria).

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "utilizadores_select" ON utilizadores
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR id = auth.uid()
    OR (
      organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
      AND papel != 'super_admin'
    )
  );

-- INSERT
CREATE POLICY "utilizadores_insert" ON utilizadores
  FOR INSERT WITH CHECK (
    -- Super Admin pode criar qualquer um
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR
    -- Admin pode criar contabilistas e clientes da sua org
    (
      (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
      AND organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND papel IN ('contabilista', 'cliente')
      AND (
        papel != 'cliente'
        OR (SELECT pode_registar_clientes FROM organizacoes WHERE id = organizacao_id)
      )
    )
  );
```

---

## 4. Tabela: `empresas`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org |  Atribuídas |  Atribuídas |
| INSERT |  |  (sua org) |  |  |
| UPDATE |  |  (sua org) |  |  |
| DELETE |  (soft) |  (soft) |  |  |

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "empresas_select" ON empresas
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
    OR id IN (SELECT empresa_id FROM contabilista_empresas WHERE contabilista_id = auth.uid())
    OR id IN (SELECT empresa_id FROM cliente_empresas WHERE cliente_id = auth.uid())
  );

-- INSERT: Super Admin ou Admin da mesma org
CREATE POLICY "empresas_insert" ON empresas
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
  );

-- UPDATE: Super Admin ou Admin da mesma org
CREATE POLICY "empresas_update" ON empresas
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR (
      organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
    )
  );
```

---

## 5. Tabela: `contabilista_empresas`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org |  Próprias |  |
| INSERT |  |  (sua org) |  |  |
| UPDATE |  |  (sua org) |  |  |
| DELETE |  |  (sua org) |  |  |

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "contabilista_empresas_select" ON contabilista_empresas
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR contabilista_id = auth.uid()
    OR empresa_id IN (
      SELECT id FROM empresas
      WHERE organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
    )
  );

-- INSERT/UPDATE/DELETE: apenas Super Admin ou Admin da org da empresa
CREATE POLICY "contabilista_empresas_write" ON contabilista_empresas
  FOR ALL USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR empresa_id IN (
      SELECT id FROM empresas
      WHERE organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
    )
  );
```

---

## 6. Tabela: `cliente_empresas`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org |  |  Próprias |
| INSERT |  |  (se `pode_registar_clientes`) |  |  |
| UPDATE |  |  (sua org) |  |  |
| DELETE |  |  (sua org) |  |  |

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "cliente_empresas_select" ON cliente_empresas
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR cliente_id = auth.uid()
    OR empresa_id IN (
      SELECT id FROM empresas
      WHERE organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
    )
  );

-- INSERT: Super Admin ou Admin (se pode_registar_clientes)
CREATE POLICY "cliente_empresas_insert" ON cliente_empresas
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR (
      empresa_id IN (
        SELECT id FROM empresas
        WHERE organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      )
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
      AND (SELECT pode_registar_clientes FROM organizacoes WHERE id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid()))
    )
  );
```

---

## 7. Tabela: `documentos`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org |  Empresas atribuídas |  Empresas atribuídas (apenas `ativo`) |
| INSERT |  |  (sua org) |  (empresas atribuídas) |  |
| UPDATE |  |  (aprovação/rejeição) |  (próprios docs, metadados) |  |
| DELETE |  (soft) |  (soft) |  |  |

### Estados do Documento

| Estado | Visível para | Descrição |
|--------|-------------|-----------|
| `ativo` | Todos com permissão | Versão aprovada e atual |
| `pendente` | Admin (aprovação), Contabilista (criador) | Nova versão à espera de aprovação |
| `rejeitado` | Admin, Contabilista (criador), auditoria | Versão rejeitada pelo admin |
| `arquivado` | Admin, Contabilista | Versão anterior substituída |
| `eliminado` | Admin, Super Admin (auditoria) | Soft delete, 90 dias até remoção física |

### Regras Específicas

- **Contabilista** pode fazer upload → cria documento com `estado = 'pendente'` se for substituição, ou `ativo` se for novo.
- **Contabilista** pode editar metadados (`tipo_documento`, `ano`, `periodo`, `notas`) de documentos que criou, desde que `estado != 'eliminado'`.
- **Contabilista** NUNCA pode alterar `estado` diretamente.
- **Admin** aprova pendente → novo fica `ativo`, antigo fica `arquivado`.
- **Admin** rejeita pendente → novo fica `rejeitado`, antigo mantém `ativo`.
- **Admin** elimina → `estado = 'eliminado'`, `data_soft_delete = NOW()`.
- **Cliente** apenas vê documentos `estado = 'ativo'`.

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "documentos_select" ON documentos
  FOR SELECT USING (
    -- Super Admin vê tudo
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR
    -- Admin vê tudo da sua org
    (
      organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
    )
    OR
    -- Contabilista vê documentos das empresas atribuídas
    (
      empresa_id IN (SELECT empresa_id FROM contabilista_empresas WHERE contabilista_id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'contabilista'
    )
    OR
    -- Cliente vê apenas ativos das empresas atribuídas
    (
      estado = 'ativo'
      AND empresa_id IN (SELECT empresa_id FROM cliente_empresas WHERE cliente_id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'cliente'
    )
  );

-- INSERT
CREATE POLICY "documentos_insert" ON documentos
  FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR
    (
      organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (
        (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
        OR (
          (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'contabilista'
          AND empresa_id IN (SELECT empresa_id FROM contabilista_empresas WHERE contabilista_id = auth.uid())
        )
      )
    )
  );

-- UPDATE
CREATE POLICY "documentos_update" ON documentos
  FOR UPDATE USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR
    -- Admin pode atualizar tudo da sua org (aprovações, etc.)
    (
      organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'admin'
    )
    OR
    -- Contabilista pode editar metadados dos seus próprios documentos
    (
      criado_por = auth.uid()
      AND (SELECT papel FROM utilizadores WHERE id = auth.uid()) = 'contabilista'
      AND estado IN ('ativo', 'pendente', 'rejeitado', 'arquivado')
    )
  );
```

---

## 8. Tabela: `log_acessos`

| Ação | Super Admin | Admin | Contabilista | Cliente |
|------|:-----------:|:-----:|:------------:|:-------:|
| SELECT |  Todas |  Da sua org |  Próprio |  Próprio |
| INSERT |  (sistema) |  (sistema) |  (sistema) |  (sistema) |
| UPDATE |  |  |  |  |
| DELETE |  |  |  |  |

### Regras

- **INSERT** apenas via trigger ou server action (nunca diretamente pelo utilizador).
- **Imutável** após criação.
- Contabilista/Cliente vê apenas os seus próprios logs.

### RLS Policies (exemplo SQL)

```sql
-- SELECT
CREATE POLICY "log_acessos_select" ON log_acessos
  FOR SELECT USING (
    auth.uid() IN (SELECT id FROM utilizadores WHERE papel = 'super_admin')
    OR
    -- Admin vê logs da sua org
    documento_id IN (
      SELECT id FROM documentos
      WHERE organizacao_id = (SELECT organizacao_id FROM utilizadores WHERE id = auth.uid())
    )
    OR utilizador_id = auth.uid()
  );

-- INSERT: apenas via service role ou função segura
CREATE POLICY "log_acessos_insert" ON log_acessos
  FOR INSERT WITH CHECK (false);  -- Inserido via Edge Function/Server Action com service role
```

---

## 9. Fluxo de Aprovação de Documentos (Diagrama)

```
Contabilista faz upload de NOVO documento
     estado = 'ativo' (não precisa de aprovação, é a primeira versão)

Contabilista faz upload de SUBSTITUIÇÃO
     Guarda novo ficheiro
     Cria registo com estado = 'pendente'
     Guarda referência: substitui_id = documento antigo
     Notifica Admin (badge na UI)

Admin vê lista de pendentes
     APROVA
        Novo documento: estado = 'ativo'
        Antigo documento: estado = 'arquivado'
        Log: "aprovou substituição"
     REJEITA
         Novo documento: estado = 'rejeitado'
         Antigo documento: mantém 'ativo'
         Log: "rejeitou substituição"

Documento 'rejeitado' ou 'eliminado'
     data_soft_delete = NOW()
         Após 90 dias: job automático elimina ficheiro + registo
```

---

## 10. Fluxo de Eliminação com 90 Dias

```
Admin clica "Eliminar" no documento
     estado = 'eliminado'
         data_soft_delete = NOW()
             Desaparece da UI normal
                 Visível apenas em painel de auditoria/reciclagem
                     Job diário verifica: data_soft_delete < NOW() - INTERVAL '90 days'
                         ELIMINAÇÃO FÍSICA: ficheiro do storage + registo da BD
```

### Implementação do Job

**Opção A (recomendada):** Supabase Edge Function + cron (pg_cron ou trigger externo)
**Opção B:** Server Action invocada por serviço externo (Vercel Cron, GitHub Actions, etc.)

```sql
-- Exemplo de query de limpeza (executada com service role)
DELETE FROM documentos
WHERE estado IN ('rejeitado', 'eliminado')
  AND data_soft_delete < NOW() - INTERVAL '90 days';
```

**Nota:** A eliminação do ficheiro em R2/Storage deve ser feita **antes** ou **em conjunto** com a eliminação do registo, para não deixar ficheiros órfãos.

---

## 11. Checklist de Segurança Pré-Deploy

- [ ] RLS ativado em **todas** as tabelas
- [ ] Nenhuma tabela com `FOR ALL USING (true)`
- [ ] Service role key **nunca** no cliente
- [ ] `organizacao_id` preenchido em **todos** os registos
- [ ] Policies testadas com utilizadores de cada role
- [ ] Portal do cliente não expõe rotas de admin (verificação de redirect por role)
- [ ] Upload de ficheiros valida tipo (PDF, JPG, PNG) e tamanho máximo no server action
- [ ] Log de acessos registado em todas as ações de visualização/download
