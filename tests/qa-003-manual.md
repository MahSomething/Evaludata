# QA-003: Testar CRUD de Empresas e Atribuicoes
> Plano de Teste Manual — Epico 4: Gestao de Empresas
> Data: 2026-08-16
> Tester: _______________
> Ambiente: Local (localhost:3000) / Staging
> Estado: [ ] Em curso  [ ] Concluido

---

## Pre-requisitos

- [ ] Projeto a correr: `npm run dev` (localhost:3000)
- [ ] Supabase local a correr: `supabase start`
- [ ] Migrations aplicadas: `supabase db reset`
- [ ] Seed data presente (Super Admin + tipos de documento)
- [ ] Navegador: Chrome/Firefox (modo incognito para sessoes isoladas)

---

## Dados de Teste

| Role | Email | Password | Organizacao |
|------|-------|----------|-------------|
| Super Admin | (seed) | (seed) | Evaludata HQ |
| Admin | admin@teste.com | (criar) | Teste Lda |
| Contabilista A | contA@teste.com | (criar) | Teste Lda |
| Contabilista B | contB@teste.com | (criar) | Teste Lda |
| Cliente X | clienteX@teste.com | N/A (OTP) | Teste Lda |

---

## Parte 1: Criar Dados de Teste (Setup)

### 1.1 Criar organizacao "Teste Lda"
```sql
-- SQL Editor (service role)
INSERT INTO organizacoes (id, nome, nuit, owner_id, pode_registar_clientes, ativa)
VALUES (
  gen_random_uuid(),
  'Teste Lda',
  '123456789',
  (SELECT id FROM auth.users WHERE email = 'super@evaludata.com'),
  true,
  true
);
```

### 1.2 Criar utilizadores de teste
Faca login como Super Admin e crie:
- [ ] Admin da "Teste Lda"
- [ ] Contabilista A da "Teste Lda"
- [ ] Contabilista B da "Teste Lda"
- [ ] Cliente X da "Teste Lda" (com telemovel: 258841234567)

---

## Parte 2: CRUD de Empresas

### 2.1 Criar Empresa (C)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.1.1 | Login como Admin | Redirecionado para /dashboard | | [ ] |
| 2.1.2 | Clicar "Empresas" no sidebar | Lista de empresas (vazia ou com dados) | | [ ] |
| 2.1.3 | Clicar "Nova Empresa" | Formulario aparece | | [ ] |
| 2.1.4 | Preencher: Nome="Empresa Alfa", NUIT="123456789", Contacto="258841111111" | Campos preenchidos | | [ ] |
| 2.1.5 | Clicar "Guardar" | Sucesso, redireciona para lista, empresa aparece | | [ ] |
| 2.1.6 | Verificar NUIT na lista | "123456789" visivel | | [ ] |

### 2.2 Criar Empresa com NUIT invalido (Validacao)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.2.1 | Clicar "Nova Empresa" | Formulario aparece | | [ ] |
| 2.2.2 | Preencher Nome="Empresa Beta", NUIT="123" (menos de 9) | Erro de validacao: "NUIT deve ter 9 digitos" | | [ ] |
| 2.2.3 | Preencher NUIT="1234567890" (mais de 9) | Erro de validacao | | [ ] |
| 2.2.4 | Deixar Nome vazio | Erro de validacao: "Nome deve ter no minimo 2 caracteres" | | [ ] |

### 2.3 Listar Empresas (R)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.3.1 | Ver lista de empresas | "Empresa Alfa" aparece com estado "Ativa" | | [ ] |
| 2.3.2 | Filtro nome: digitar "Alfa" | Apenas "Empresa Alfa" aparece | | [ ] |
| 2.3.3 | Filtro nome: digitar "Inexistente" | Empty state: "Nenhuma empresa corresponde aos filtros" | | [ ] |
| 2.3.4 | Filtro NUIT: digitar "123456789" | "Empresa Alfa" aparece | | [ ] |
| 2.3.5 | Clicar "Limpar" | Filtros resetados, todas as empresas aparecem | | [ ] |
| 2.3.6 | Criar 12 empresas | Paginacao aparece (10 por pagina) | | [ ] |
| 2.3.7 | Clicar pagina 2 | Proximas empresas aparecem | | [ ] |

### 2.4 Editar Empresa (U)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.4.1 | Clicar "Editar" na "Empresa Alfa" | Formulario pre-preenchido | | [ ] |
| 2.4.2 | Alterar Contacto para "258842222222" | Campo atualizado | | [ ] |
| 2.4.3 | Clicar "Guardar" | Sucesso, redireciona para lista | | [ ] |
| 2.4.4 | Verificar Contacto na lista | "258842222222" visivel | | [ ] |
| 2.4.5 | Clicar no nome "Empresa Alfa" | Pagina de detalhe abre | | [ ] |
| 2.4.6 | Verificar info no detalhe | Nome, NUIT, Contacto, Estado "Ativa" corretos | | [ ] |

### 2.5 Eliminar Empresa (Soft Delete)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.5.1 | Clicar icone lixo na "Empresa Alfa" | Empresa desaparece da lista (ativas) | | [ ] |
| 2.5.2 | Marcar "Mostrar inativas" | "Empresa Alfa" aparece com estado "Inativa" | | [ ] |
| 2.5.3 | Clicar icone rotacao na "Empresa Alfa" | Estado muda para "Ativa", aparece na lista normal | | [ ] |

### 2.6 Isolamento Multi-Tenant

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 2.6.1 | Criar empresa como Admin da "Teste Lda" | Sucesso | | [ ] |
| 2.6.2 | Login como Admin de OUTRA organizacao | Apenas empresas da sua org visiveis | | [ ] |
| 2.6.3 | Tentar aceder `/empresas/[id-da-TesteLda]` | 404 ou acesso negado | | [ ] |

---

## Parte 3: Atribuicao de Contabilistas

### 3.1 Atribuir Contabilista

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 3.1.1 | Na "Empresa Alfa", clicar "Atribuir" | Pagina de atribuicao abre | | [ ] |
| 3.1.2 | Verificar lista "Contabilistas Atribuidos" | Vazia | | [ ] |
| 3.1.3 | Selecionar "Contabilista A" no dropdown | Selecionado | | [ ] |
| 3.1.4 | Clicar "Atribuir Contabilista" | Sucesso, aparece na lista | | [ ] |
| 3.1.5 | Atribuir "Contabilista B" | Ambos aparecem na lista | | [ ] |

### 3.2 Remover Atribuicao

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 3.2.1 | Clicar "X" ao lado de "Contabilista A" | Desaparece da lista | | [ ] |
| 3.2.2 | Verificar pagina de detalhe | Apenas "Contabilista B" listado | | [ ] |

### 3.3 Contabilista so ve empresas atribuidas

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 3.3.1 | Login como "Contabilista A" | Dashboard abre | | [ ] |
| 3.3.2 | Ir para "Empresas" | Apenas empresas atribuidas visiveis | | [ ] |
| 3.3.3 | Criar empresa como Contabilista | Erro: "Permissao insuficiente" | | [ ] |

---

## Parte 4: Atribuicao de Clientes

### 4.1 Atribuir Cliente

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 4.1.1 | Login como Admin | Dashboard abre | | [ ] |
| 4.1.2 | Na "Empresa Alfa", clicar "Gerir" em Clientes | Pagina atribuir-cliente abre | | [ ] |
| 4.1.3 | Selecionar "Cliente X" no dropdown | Selecionado | | [ ] |
| 4.1.4 | Clicar "Atribuir Cliente" | Sucesso, aparece na lista | | [ ] |

### 4.2 Remover Atribuicao de Cliente

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 4.2.1 | Clicar "X" ao lado de "Cliente X" | Desaparece da lista | | [ ] |

### 4.3 Organizacao sem `pode_registar_clientes`

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 4.3.1 | SQL: `UPDATE organizacoes SET pode_registar_clientes = false WHERE nome = 'Teste Lda'` | — | | [ ] |
| 4.3.2 | Tentar atribuir cliente | Erro: "Organizacao nao permite registar clientes" | | [ ] |
| 4.3.3 | Reverter: `UPDATE organizacoes SET pode_registar_clientes = true` | — | | [ ] |

---

## Parte 5: Dashboard

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 5.1 | Card "Empresas" mostra numero correto | = numero de empresas ativas da org | | [ ] |
| 5.2 | Card "Documentos" mostra "0" | Nenhum documento ainda | | [ ] |
| 5.3 | Card "Clientes" mostra numero correto | = numero de clientes ativos da org | | [ ] |

---

## Parte 6: Auditoria (Logger)

| Passo | Acao | Resultado Esperado | Resultado Real | OK? |
|-------|------|-------------------|----------------|-----|
| 6.1 | Verificar logs do servidor (terminal) | Logs de criar/editar/eliminar empresa visiveis | | [ ] |
| 6.2 | Verificar que NUIT nao aparece nos logs | Redacao ativa (*** ou similar) | | [ ] |
| 6.3 | Verificar que emails nao aparecem | Redacao ativa | | [ ] |

---

## Parte 7: Testes de Seguranca (Cenarios Criticos)

| # | Cenario | Passos | Resultado Esperado | OK? |
|---|---------|--------|-------------------|-----|
| 7.1 | SQL Injection no filtro nome | Filtro: `"'; DROP TABLE empresas; --`" | Nenhum erro, nenhuma tabela eliminada | [ ] |
| 7.2 | SQL Injection no filtro NUIT | Filtro: `123 OR 1=1` | Apenas resultados com "123" no NUIT | [ ] |
| 7.3 | XSS no nome da empresa | Criar empresa: `<script>alert('xss')</script>` | Nome escapado, script nao executa | [ ] |
| 7.4 | Aceder pagina sem login | Abrir `/empresas` em janela anonima | Redirect para `/login` | [ ] |
| 7.5 | Aceder /login com sessao ativa | Logado → abrir `/login` | Redirect para `/dashboard` | [ ] |
| 7.6 | Brute force login | 6 tentativas erradas em <15min | Rate limit ativo (esperar ou erro) | [ ] |
| 7.7 | Aceder /dashboard como Cliente | Login como Cliente → /dashboard | Redirect para `/portal` | [ ] |

---

## Resumo dos Resultados

| Categoria | Total | Passou | Falhou | N/A |
|-----------|-------|--------|--------|-----|
| CRUD Empresas | 25 | | | |
| Atribuicao Contabilistas | 10 | | | |
| Atribuicao Clientes | 7 | | | |
| Dashboard | 3 | | | |
| Auditoria | 3 | | | |
| Seguranca | 7 | | | |
| **TOTAL** | **55** | | | |

---

## Bugs Encontrados

| ID | Descricao | Severidade | Epico Afetado | Estado |
|----|-----------|------------|---------------|--------|
| | | | | |

---

## Assinatura

Tester: _______________________  Data: _______________________

Revisor: ______________________  Data: _______________________
