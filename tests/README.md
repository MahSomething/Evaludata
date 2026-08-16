# Testes do Projeto Evaludata

## Estrutura

```
tests/
├── db/
│   ├── schema_validation.sql      # QA-001: Validacao do schema
│   └── rls-permissions-test.sql   # QA-003 (auto): Testes RLS
└── qa-003-manual.md               # QA-003 (manual): Plano de teste CRUD
```

---

## QA-001: Validacao do Schema

### Como executar

1. Abra o **SQL Editor** do Supabase (Studio local ou remoto)
2. Cole o conteudo de `tests/db/schema_validation.sql`
3. Clique **Run**
4. Verifique as mensagens no output

### O que verifica

- [x] 9 tabelas existem
- [x] RLS ativado em todas
- [x] FKs criticas presentes
- [x] CHECK constraints (papel, estado)
- [x] Indices criticos
- [x] Funcao `custom_access_token_hook`
- [x] Trigger `atualizar_updated_at`
- [x] Seed data (tipos_documento)
- [x] FK bloqueia IDs invalidos

### Resultado esperado

```
[OK] Todas as 9 tabelas existem.
[OK] RLS ativado em todas as tabelas.
[OK] Todas as FKs criticas existem.
[OK] CHECK constraints existem.
[OK] Indices criticos existem.
[OK] Funcao custom_access_token_hook existe.
[OK] Trigger atualizar_updated_at existe.
[OK] Seed data presente: 7 tipos de documento.
[OK] FK funciona corretamente (bloqueou ID invalido).
VALIDACAO CONCLUIDA COM SUCESSO
```

---

## QA-003: Testar CRUD de Empresas e Atribuicoes

### Parte A — Testes RLS Automatizados

**Ficheiro:** `tests/db/rls-permissions-test.sql`

#### Pre-requisitos
- Service Role Key (para inserir em `auth.users`)
- SQL Editor com permissao de escrita

#### Como executar
1. Abra o SQL Editor
2. Cole o conteudo de `rls-permissions-test.sql`
3. Clique **Run**
4. Verifique as mensagens `[OK]` ou `[FALHA]`

#### O que testa
- Anonimo nao ve empresas
- Admin ve todas as empresas da org
- Contabilista so ve empresas atribuidas
- Cliente so ve empresas atribuidas
- Cliente so ve documentos `ativo`
- Contabilista ve documentos (ativo + pendente)
- `log_acessos` e imutavel (UPDATE/DELETE bloqueados)

#### Limpeza
O script inclui uma secao de LIMPEZA comentada no final. Descomente se quiser remover os dados de teste.

---

### Parte B — Teste Manual

**Ficheiro:** `tests/qa-003-manual.md`

#### Pre-requisitos
- Projeto a correr: `npm run dev`
- Supabase local: `supabase start`
- Navegador com modo incognito

#### Como executar
1. Leia o plano completo em `qa-003-manual.md`
2. Siga os passos na ordem indicada
3. Preencha a coluna "Resultado Real" e marque `[x]` em "OK?"
4. Registe bugs na tabela "Bugs Encontrados"

#### Categorias testadas
- **CRUD Empresas:** Criar, validar NUIT, listar, filtrar, paginar, editar, soft delete, restaurar
- **Atribuicao Contabilistas:** Atribuir, remover, isolamento
- **Atribuicao Clientes:** Atribuir, remover, validar `pode_registar_clientes`
- **Dashboard:** Contagens reais
- **Auditoria:** Logs com redacao
- **Seguranca:** SQL injection, XSS, brute force, redirecionamentos

---

## Checklist Final QA-003

- [ ] QA-001 (schema) passou
- [ ] QA-003 Parte A (RLS auto) passou
- [ ] QA-003 Parte B (manual) preenchido
- [ ] Nenhum bug critico encontrado
- [ ] Todos os bugs documentados
- [ ] Assinatura do tester + revisor

---

> **Nota:** Se encontrar um bug durante o QA-003, pare imediatamente, documente-o e crie uma tarefa de bug no BACKLOG.md antes de continuar.
