# SECURITY_CHECKLIST.md

> Mapeamento de cenarios de seguranca às tarefas do backlog.
> Cada cenario indica: descricao, fase de implementacao, tarefa responsavel, e criterio de aceitacao.
> Ultima atualizacao: 2026-08-14

---

## Legenda

| Status | Significado |
|--------|-------------|
| [ ] PENDENTE | Ainda nao implementado |
| [x] IMPLEMENTADO | Ja no codigo, testado e commitado |
| [~] PARCIAL | Implementado parcialmente, necessita revisao |

---

## Cenario 1: Secrets no codigo (hardcoded)

**Descricao:** API keys, tokens, passwords escritos diretamente no codigo fonte.

**Impacto:** CRITICO — qualquer pessoa com acesso ao repo ou ao build tem acesso total aos servicos.

**Fase de implementacao:** INF-001 (Setup inicial)

**Tarefa:** Configurar `.env.local` + `.gitignore` + `.env.example`

**Criterios de aceitacao:**
- [x] `.env.local` no `.gitignore`
- [x] `.env.example` com placeholders vazios
- [x] Nenhum secret hardcoded no codigo
- [x] Pre-commit hook bloqueia commits com `.env` files

**Pre-commit hook:** `.git/hooks/pre-commit` (secao 1 e 2)

---

## Cenario 2: Secrets em console.log

**Descricao:** `console.log(user)`, `console.log(session)`, `console.log(process.env)` em producao.

**Impacto:** ALTO — logs do Vercel sao acessiveis a toda a equipa; browser console e visivel ao utilizador.

**Fase de implementacao:** INF-005 (Zod + RHF) + Todas as tarefas BE/FE

**Tarefa:** Usar `lib/logger.ts` em vez de `console.log`

**Criterios de aceitacao:**
- [x] `lib/logger.ts` criado com redaction automatica
- [x] `logger.debug/info/warn/error` redactam campos sensiveis
- [x] `logger.error` nao expoe `err.stack` ao cliente
- [x] Pre-commit hook avisa sobre `console.log` com palavras-chave sensiveis

**Pre-commit hook:** `.git/hooks/pre-commit` (secao 3)

---

## Cenario 3: Error messages reveladoras

**Descricao:** Retornar `err.message` ou `err.stack` ao cliente, revelando SQL interno ou estrutura da BD.

**Impacto:** ALTO — facilita SQL injection e reconhecimento da arquitetura.

**Fase de implementacao:** Todas as tarefas BE-xxx (Server Actions)

**Tarefa:** Padrao de retorno `{ success, error, data }` com mensagens genericas

**Criterios de aceitacao:**
- [ ] Todas as Server Actions retornam `{ success: boolean, error?: string, data?: T }`
- [ ] `error` e sempre uma mensagem generica ("Erro ao processar pedido")
- [ ] Erro real e logado no servidor via `logger.error`
- [ ] Nunca expor `err.stack`, `err.message` do Postgres, ou queries SQL

**Implementar em:**
- BE-001 (login), BE-003 (criar utilizador), BE-004 (CRUD empresas), BE-006 (upload), etc.

---

## Cenario 4: Stack traces em producao

**Descricao:** Next.js expoe stack traces detalhadas em paginas de erro.

**Impacto:** MEDIO — revela estrutura de pastas e dependencias.

**Fase de implementacao:** INF-009 (Deploy Vercel)

**Tarefa:** Verificar configuracao de erro do Next.js

**Criterios de aceitacao:**
- [ ] Verificar que `next.config.ts` nao tem `debug` ou `devIndicators` ativados em prod
- [ ] Pagina de erro generica (`app/error.tsx`) sem stack trace
- [ ] Testar: forcar erro em producao, verificar que nao expoe stack

---

## Cenario 5: .env copiado acidentalmente

**Descricao:** `cp .env.local .env.local.backup` e o backup e commitado.

**Impacto:** CRITICO — mesmo que o original esteja no .gitignore, o backup pode nao estar.

**Fase de implementacao:** INF-001 (Setup inicial)

**Tarefa:** `.gitignore` abrangente

**Criterios de aceitacao:**
- [x] `.gitignore` ignora `.env*` exceto `.env.example`
- [x] Pre-commit hook bloqueia qualquer `.env` file no stage

**Pre-commit hook:** `.git/hooks/pre-commit` (secao 1)

---

## Cenario 6: Screenshots com .env visivel

**Descricao:** Developer partilha screenshot do VS Code onde `.env.local` esta aberto com valores reais.

**Impacto:** CRITICO — o secret e exposto mesmo sem estar no codigo.

**Fase de implementacao:** Processo de equipa (nao e codigo)

**Tarefa:** Documentar regras de comunicacao

**Criterios de aceitacao:**
- [ ] Documentar em SECURITY.md: "Nunca partilhar ecra com .env aberto"
- [ ] Documentar em SECURITY.md: "Nunca fazer screenshot de codigo com secrets"
- [ ] Pre-commit hook avisa quando imagens sao commitadas

**Pre-commit hook:** `.git/hooks/pre-commit` (secao 6)

---

## Cenario 7: Commit com secrets no historico

**Descricao:** Secret e commitado, depois removido num commit seguinte. O secret continua no historico do Git.

**Impacto:** CRITICO — qualquer pessoa com acesso ao repo pode ver o historico.

**Fase de implementacao:** Processo de equipa (nao e codigo)

**Tarefa:** Procedimento de remocao de secrets do historico

**Criterios de aceitacao:**
- [ ] Documentar em SECURITY.md: como usar `git filter-repo` ou BFG Repo-Cleaner
- [ ] Documentar: rotacionar secret imediatamente, mesmo apos remocao do historico
- [ ] Documentar: nunca usar `git push --force` em branch partilhada sem avisar

---

## Cenario 8: Service Role Key no cliente

**Descricao:** `SUPABASE_SERVICE_ROLE_KEY` usada em Client Component ou exposta no browser.

**Impacto:** CRITICO — bypass total do RLS, acesso a todos os dados.

**Fase de implementacao:** INF-002 (Supabase SSR)

**Tarefa:** Separacao clara dos 3 clientes Supabase

**Criterios de aceitacao:**
- [x] `lib/supabase/client.ts` usa apenas `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- [x] `lib/supabase/server.ts` usa `SUPABASE_SERVICE_ROLE_KEY` apenas onde necessario
- [x] Nenhuma importacao de `server.ts` em ficheiros Client Component
- [x] Verificacao automatica no build (ESLint rule ou script)

---

## Cenario 9: Upload de ficheiros maliciosos

**Descricao:** Ficheiro `.exe` renomeado para `.pdf`, ou PDF com JavaScript embutido.

**Impacto:** ALTO — vetor de ataque para clientes que fazem download.

**Fase de implementacao:** BE-006 (Server Action de upload)

**Tarefa:** Validacao rigorosa de ficheiros

**Criterios de aceitacao:**
- [ ] Validar magic bytes no servidor (nao apenas extensao)
- [ ] Lista branca: `application/pdf`, `image/jpeg`, `image/png`
- [ ] Limite de tamanho: 50MB
- [ ] Nome do ficheiro sanitizado (remover `../`, caracteres especiais, null bytes)
- [ ] Servir com `Content-Disposition: attachment` (evitar execucao inline)

---

## Cenario 10: Rate limiting ausente

**Descricao:** Brute force em login, spam de OTP, ou flood de upload.

**Impacto:** ALTO — negacao de servico ou acesso nao autorizado.

**Fase de implementacao:** BE-001 (login) + BE-012 (OTP)

**Tarefa:** Rate limiting em acoes criticas

**Criterios de aceitacao:**
- [ ] Login: max 5 tentativas / 15 min / IP
- [ ] OTP: max 3 tentativas / 10 min / telefone
- [ ] Upload: max 10 uploads / hora / utilizador
- [ ] Implementar via `lru-cache` ou `upstash/ratelimit`

---

## Cenario 11: Sessao exposta apos logout

**Descricao:** Utilizador faz logout, mas o token JWT continua valido ate expirar.

**Impacto:** MEDIO — se alguem roubar o token, pode usar ate expirar.

**Fase de implementacao:** BE-002 (logout) + BE-013 (validar OTP)

**Tarefa:** Invalidacao de sessao

**Criterios de aceitacao:**
- [ ] Logout limpa cookies imediatamente
- [ ] Sessao JWT custom do portal: expiracao curta (1h)
- [ ] Considerar blacklist de tokens revogados (Redis/Supabase) para invalidacao imediata

---

## Cenario 12: Acesso a dados de outra organizacao

**Descricao:** Contabilista da Organizacao A acede a documentos da Organizacao B.

**Impacto:** CRITICO — violacao de confidencialidade multi-tenant.

**Fase de implementacao:** DB-008 a DB-010 (RLS) + Todas as BE-xxx

**Tarefa:** RLS + validacao dupla

**Criterios de aceitacao:**
- [x] RLS ativado em TODAS as tabelas
- [x] Policies usam Custom Claims (sem subqueries)
- [x] Server Actions validam `organizacao_id` antes da operacao
- [x] Teste de penetracao: verificar que nenhum role acede a dados de outra org

---

## Cenario 13: Cliente acede a documentos de outra empresa

**Descricao:** Cliente X (Empresa A) ve documentos da Empresa B.

**Impacto:** CRITICO — violacao de confidencialidade cliente.

**Fase de implementacao:** BE-014 (listar documentos cliente) + RLS

**Tarefa:** Filtragem por `cliente_empresas`

**Criterios de aceitacao:**
- [ ] Cliente so ve documentos `estado = 'ativo'`
- [ ] Cliente so ve empresas em `cliente_empresas`
- [ ] Teste: Cliente X com 1 empresa nao ve documentos de outra empresa
- [ ] Teste: Cliente X com 3 empresas ve apenas as 3

---

## Cenario 14: SQL Injection

**Descricao:** Input do cliente e concatenado diretamente em query SQL.

**Impacto:** CRITICO — acesso total a base de dados.

**Fase de implementacao:** Todas as tarefas BE-xxx

**Tarefa:** Usar sempre parametros preparados

**Criterios de aceitacao:**
- [ ] Nenhuma concatenacao de string em queries SQL
- [ ] Supabase client ja usa parametros preparados (verificar que nao usamos raw SQL)
- [ ] Validar inputs com Zod antes de tocar na BD
- [ ] Teste: tentar SQL injection nos filtros (nome, NUIT, tipo)

---

## Cenario 15: XSS (Cross-Site Scripting)

**Descricao:** Nome de ficheiro ou nota com `<script>alert('xss')</script>` e renderizado sem escaping.

**Impacto:** ALTO — roubo de sessao, acoes em nome do utilizador.

**Fase de implementacao:** Todas as tarefas FE-xxx

**Tarefa:** Escaping de output

**Criterios de aceitacao:**
- [ ] React faz escaping automatico (nao usar `dangerouslySetInnerHTML`)
- [ ] Nomes de ficheiros escapados antes de renderizar
- [ ] Notas e metadados escapados
- [ ] Teste: upload de ficheiro com nome `<script>alert(1)</script>.pdf`

---

## Cenario 16: CSRF (Cross-Site Request Forgery)

**Descricao:** Site malicioso faz POST para `/api/delete-documento` com cookie da vitima.

**Impacto:** MEDIO — acoes nao intencionais.

**Fase de implementacao:** INF-002 (Supabase SSR) + Todas as BE-xxx

**Tarefa:** Protecao CSRF

**Criterios de aceitacao:**
- [ ] Server Actions do Next.js 16 ja incluem protecao CSRF nativa
- [ ] Nunca usar GET para acoes destrutivas
- [ ] Validar `Origin` e `Referer` em endpoints criticos

---

## Cenario 17: Headers de seguranca ausentes

**Descricao:** Browser nao recebe headers que previnem XSS, clickjacking, etc.

**Impacto:** MEDIO — aumenta superficie de ataque.

**Fase de implementacao:** INF-001 (Setup Next.js)

**Tarefa:** Configurar headers no `next.config.ts`

**Criterios de aceitacao:**
- [x] `X-Content-Type-Options: nosniff`
- [x] `X-Frame-Options: DENY`
- [x] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] Adicionar `Content-Security-Policy` (CSP) em producao

---

## Cenario 18: Backup e recuperacao

**Descricao:** Perda de dados por falha tecnica, ransomware, ou erro humano.

**Impacto:** CRITICO — perda permanente de documentos fiscais.

**Fase de implementacao:** INF-009 (Deploy) + Processo

**Tarefa:** Estrategia de backup 3-2-1

**Criterios de aceitacao:**
- [ ] Supabase Pro: backup automatico diario (ativar no plano)
- [ ] R2: versioning ativado no bucket
- [ ] Teste de restauracao: a cada 3 meses, restaurar backup em ambiente de teste
- [ ] Documentar procedimento de recuperacao

---

## Cenario 19: GDPR/LGPD — Direito ao esquecimento

**Descricao:** Cliente pede eliminacao de todos os seus dados.

**Impacto:** LEGAL — multa se nao cumprido.

**Fase de implementacao:** BE-016 (log de acessos) + Processo

**Tarefa:** Endpoint de eliminacao completa

**Criterios de aceitacao:**
- [ ] Endpoint para exportar todos os dados do cliente (JSON)
- [ ] Endpoint para eliminar/anonimizar dados do cliente
- [ ] Soft delete em utilizadores (nao eliminar fisicamente — preservar auditoria)
- [ ] Documentos do cliente: manter por 10 anos (obrigacao fiscal), mas anonimizar metadados

---

## Cenario 20: Notificacao de breach

**Descricao:** Vazamento de dados — obrigacao legal de notificar em 72h.

**Impacto:** LEGAL — multa da CNPD (ou equivalente em Mocambique).

**Fase de implementacao:** Processo de equipa

**Tarefa:** Plano de resposta a incidentes

**Criterios de aceitacao:**
- [ ] Documentar em SECURITY.md: quem notifica, como, em quanto tempo
- [ ] Template de email para comunicar a clientes afetados
- [ ] Contacto da autoridade de protecao de dados de Mocambique

---

## Resumo por Tarefa

| Tarefa | Cenarios de seguranca |
|--------|----------------------|
| INF-001 | Cenario 1, 5, 17 |
| INF-002 | Cenario 8, 16 |
| INF-003 | — |
| INF-005 | Cenario 2 |
| BE-001 | Cenario 3, 10 |
| BE-002 | Cenario 11 |
| BE-003 | Cenario 3 |
| BE-004 | Cenario 3, 12, 14 |
| BE-006 | Cenario 3, 9 |
| BE-012 | Cenario 10 |
| BE-013 | Cenario 11 |
| BE-014 | Cenario 13 |
| BE-016 | Cenario 19 |
| FE-001 a FE-012 | Cenario 3, 15 |
| INF-009 | Cenario 4, 18 |
| QA-008 | Todos (pentest) |

---

## Checklist Pre-Deploy

Antes de colocar em producao:

- [ ] Todos os cenarios CRITICO e ALTO implementados
- [ ] Pre-commit hook ativo em todas as maquinas de desenvolvimento
- [ ] `lib/logger.ts` usado em todo o codigo (zero `console.log` em producao)
- [ ] Teste de penetracao leve (QA-008) passou
- [ ] Backup configurado e testado
- [ ] Plano de resposta a incidentes documentado
- [ ] Secrets rotacionados (nao usar os mesmos que em desenvolvimento)
