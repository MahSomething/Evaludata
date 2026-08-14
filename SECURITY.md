# SECURITY.md

> Diretrizes de seguranca para o Sistema de Gestao Documental.
> Dados processados: NUIT, documentos fiscais, extratos bancarios, relatorios IRS/IVA.
> Classificacao de risco: ALTO (dados pessoais + dados empresariais sensiveis).
> Ultima atualizacao: 2026-08-14

---

## 1. Classificacao de Dados

| Nivel | Dados | Protecao |
|-------|-------|----------|
| **CRITICO** | Documentos fiscais (IRS, IVA, extratos bancarios), NUIT, contactos | Criptografia em repouso + transito, RLS estrita, auditoria completa |
| **SENSIVEL** | Nomes, emails, telefones, logs de acesso | RLS, hashing, retencao limitada |
| **INTERNO** | Metadados de documentos, configuracoes do sistema | RLS basica, acesso autenticado |

---

## 2. Pontos Criticos (Must Implement)

### 2.1 Row Level Security (RLS) — ZERO EXCECOES

- TODAS as tabelas tem RLS ativado.
- NENHUMA policy com `USING (true)` ou `WITH CHECK (true)`.
- NENHUMA tabela acessivel por `anon` (utilizador nao autenticado).
- Service Role Key NUNCA exposta no cliente (browser, mobile, logs).
- Service Role Key NUNCA commitada no Git (usar `.env.local` + `.gitignore` + GitHub Secrets).

### 2.2 Custom Claims no JWT (Performance + Seguranca)

- NUNCA usar subqueries em RLS policies (ex: `organizacao_id = (SELECT ... FROM utilizadores)`).
- SEMPRE injetar `organizacao_id` e `papel` no JWT via `custom_access_token_hook`.
- SEMPRE validar claims no server antes de operacoes criticas (upload, delete, aprovacao).

### 2.3 Upload de Ficheiros — Validacao Rigida

- Validar **magic bytes** no servidor (primeiros bytes do ficheiro), nunca apenas extensao.
- Lista branca de tipos: `application/pdf`, `image/jpeg`, `image/png`.
- Limite de tamanho: 50MB por ficheiro, 100MB por upload batch.
- Nome do ficheiro: sanitizar (remover caracteres especiais, path traversal `../`, null bytes).
- Storage: usar chaves UUID no R2, nunca o nome original do ficheiro como chave.
- Estrutura de pastas: `organizacao-id/empresa-id/documento-id.ext` (nunca expor IDs internos).

### 2.4 Autenticacao — Multi-Camadas

- Admin/Contabilista: Supabase Auth (email + password forte, min 12 caracteres).
- Cliente: OTP via WhatsApp (6 digitos, expira em 10 min, max 3 tentativas).
- Rate limiting: 5 tentativas de login / 15 min / IP.
- Rate limiting: 3 tentativas de OTP / 10 min / telefone.
- Sessoes: 8h para Admin/Contabilista, 1h para Cliente (portal).
- Logout invalida token imediatamente (se possivel) ou usa short expiry.

### 2.5 SQL Injection — Prevencao

- NUNCA concatenar strings em queries SQL.
- SEMPRE usar parametros preparados (Supabase client ja faz isto).
- NUNCA permitir `order by` ou `limit` vindos diretamente do cliente sem validacao.
- Validar todos os inputs com Zod antes de tocar na base de dados.

### 2.6 XSS (Cross-Site Scripting) — Prevencao

- NUNCA renderizar HTML vindo do cliente sem sanitizacao.
- Nomes de ficheiros, notas, metadados: escapar antes de renderizar.
- React faz escaping automatico, mas cuidado com `dangerouslySetInnerHTML` (evitar).
- Headers de seguranca no Next.js:
  ```
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
  ```

### 2.7 CSRF (Cross-Site Request Forgery) — Prevencao

- Server Actions do Next.js 16 ja incluem protecao CSRF nativa (tokens em headers).
- Nunca usar GET para acoes destrutivas (delete, update, aprovacao).
- Validar `Origin` e `Referer` em endpoints criticos.

### 2.8 Secrets e Variaveis de Ambiente

| Secret | Onde usar | Onde NUNCA estar |
|--------|-----------|------------------|
| SUPABASE_SERVICE_ROLE_KEY | Server Actions, Edge Functions | Cliente, logs, Git |
| R2_SECRET_ACCESS_KEY | Server Actions, Edge Functions | Cliente, logs, Git |
| WHATSAPP_API_KEY | Server Actions | Cliente, logs, Git |
| SESSION_SECRET / JWT_SECRET | Server (sessao custom) | Cliente, logs, Git |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | Cliente (browser) | N/A (e publica por design) |

- `.env.local` no `.gitignore`.
- `.env.example` com valores vazios/dummy para documentacao.
- Vercel: usar Environment Variables encriptadas (Production only).
- Supabase Edge Functions: usar Secrets (Dashboard ou CLI).

### 2.9 Auditoria e Imutabilidade

- `log_acessos`: INSERT apenas via trigger ou service role. NUNCA UPDATE nem DELETE.
- `documentos`: soft delete apenas (estado = 'eliminado'). DELETE fisico apenas pelo job de 90 dias.
- Todas as tabelas tem `criado_em`, `criado_por`, `atualizado_em`, `atualizado_por`.
- Backup diario da base de dados (Supabase faz isto automaticamente no plano Pro).

### 2.10 HTTPS e Transporte Seguro

- TODAS as comunicacoes via HTTPS (Vercel e Supabase ja forcam isto).
- Cookies de sessao: `Secure`, `HttpOnly`, `SameSite=Strict`.
- Signed URLs do R2: expiracao curta (upload: 5 min, download: 1h).

---

## 3. Nice-to-Have (Should Implement)

### 3.1 Criptografia em Repouso

- Supabase Postgres ja criptografa dados em repouso (AES-256).
- R2/Cloudflare ja criptografa ficheiros em repouso.
- Considerar criptografia adicional para campos ultra-sensiveis (ex: NUIT) se necessario regulatorio.

### 3.2 2FA para Admin e Super Admin

- Supabase Auth suporta TOTP (Google Authenticator, Authy).
- Obrigatorio para Super Admin. Opcional para Admin.
- Nao aplicavel a Cliente (ja usa OTP).

### 3.3 Alertas de Seguranca

- Notificacao por email quando:
  - Login de novo dispositivo/IP.
  - Tentativas de login falhadas (>5 em 15 min).
  - Documento aprovado/rejeitado.
  - Nova organizacao criada.

### 3.4 WAF (Web Application Firewall)

- Cloudflare (ja usado para R2) pode proteger o dominio Vercel.
- Regras: bloquear IPs suspeitos, limitar requests, proteger contra bots.

### 3.5 Penetration Testing Periodico

- A cada 6 meses: teste de seguranca externo (ou ferramentas como OWASP ZAP).
- Verificar: SQL injection, XSS, CSRF, broken auth, sensitive data exposure.

### 3.6 Politica de Retencao de Dados (GDPR/LGPD)

- Dados de utilizadores inativos: eliminar apos 2 anos.
- Logs de acesso: arquivar apos 1 ano, eliminar apos 3 anos.
- Documentos eliminados: ja coberto pelo job de 90 dias.
- Exportar dados do utilizador (direito de acesso): endpoint para gerar JSON com todos os dados.
- Direito ao esquecimento: endpoint para eliminar todos os dados de um cliente (soft delete + anonimizacao).

### 3.7 Monitoramento de Anomalias

- Dashboard de seguranca:
  - Logins falhados por hora.
  - Downloads por utilizador (detetar exfiltracao).
  - Documentos rejeitados (possivel tentativa de upload malicioso).
  - Acessos fora de horario.

---

## 4. Checklist de Seguranca por Tarefa

### Antes de qualquer commit

- [ ] Nenhum secret no codigo (usar `grep -r "sk-" .` ou similar).
- [ ] Nenhum `console.log` com dados sensiveis.
- [ ] Nenhum `debugger` ou breakpoint no codigo.
- [ ] `.env.local` no `.gitignore`.

### Tarefas de Base de Dados (DB-xxx)

- [ ] RLS ativado na tabela.
- [ ] Nenhuma policy com `true`.
- [ ] Subqueries evitadas em RLS (usar Custom Claims).
- [ ] Indices em colunas de pesquisa e FK.
- [ ] FK com `ON DELETE` adequado (CASCADE vs SET NULL).

### Tarefas de Backend (BE-xxx)

- [ ] Inputs validados com Zod.
- [ ] Permissoes verificadas antes da acao (nao apenas RLS).
- [ ] Rate limiting implementado.
- [ ] Erros nao revelam informacao interna (ex: nao mostrar SQL error ao cliente).
- [ ] Service Role Key usada apenas onde necessario.

### Tarefas de Frontend (FE-xxx)

- [ ] Nenhum secret no codigo do cliente.
- [ ] Formularios com validacao client-side + server-side.
- [ ] Upload valida tipo e tamanho antes de enviar.
- [ ] Dados sensiveis nao expostos em props/URL.

### Tarefas de Infra (INF-xxx)

- [ ] Variaveis de ambiente configuradas no Vercel (nunca no repo).
- [ ] HTTPS forçado.
- [ ] Headers de seguranca configurados.
- [ ] Backup configurado.

---

## 5. Resposta a Incidentes

### 5.1 Detetar

- Monitorar logs de acesso anomalos (Supabase Logs, Vercel Analytics).
- Alertas automaticos para: muitos downloads, acessos fora de horario, IPs estranhos.

### 5.2 Conter

- Revogar tokens de sessao (Supabase Auth → revoke all sessions).
- Desativar utilizador suspeito (`ativo = false`).
- Rotacionar secrets (R2, Supabase, WhatsApp).

### 5.3 Erradicar

- Identificar vetor de ataque (log analysis).
- Corrigir vulnerabilidade (patch, configuracao).
- Verificar integridade dos dados (documentos nao alterados indevidamente).

### 5.4 Recuperar

- Restaurar backup se necessario.
- Comunicar a organizacao afetada (Admin/Owner).
- Documentar incidente.

### 5.5 Aprender

- Atualizar SECURITY.md com a licao aprendida.
- Adicionar teste de regressao.
- Revisar permissoes e RLS.

---

## 6. Conformidade Regulatoria (Portugal)

### 6.1 GDPR / LGPD

- Base legal: execucao de contrato (prestacao de servicos de contabilidade).
- Direito de acesso: cliente pode pedir todos os seus dados (endpoint a implementar).
- Direito de retificacao: cliente pode pedir correcao de dados (via Admin).
- Direito ao esquecimento: cliente pode pedir eliminacao (soft delete + anonimizacao apos 90 dias).
- Direito de portabilidade: exportar dados em formato legivel (JSON).
- Notificacao de violacao: 72h para comunicar a CNPD em caso de breach.

### 6.2 Ordem dos Contabilistas Certificados (OCC)

- Retencao de documentos: minimo 10 anos (Código do IRC de Moçambique, art. 123).
- Sistema deve garantir integridade e nao repudio (assinatura digital futura).
- Acesso restrito ao profissional e cliente (confidencialidade).

### 6.3 Seguranca da Informacao (ISO 27001 — aspiracional)

- Controlo de acesso: principio do menor privilegio.
- Gestao de incidentes: processo documentado.
- Backup: 3-2-1 rule (3 copias, 2 meios, 1 offsite).

---

## 7. Contactos e Escalacao

| Situacao | Acao |
|----------|------|
| Suspeita de acesso nao autorizado | Revogar sessoes, desativar user, investigar logs |
| Vazamento de dados | Notificar CNPD em 72h, comunicar clientes afetados |
| Bug de seguranca critico | Patch imediato, rollback se necessario |
| Duvida sobre conformidade | Consultar documentacao, rever SECURITY.md |

---

## 8. Revisao

Este documento deve ser revisado:
- Apos cada incidente de seguranca.
- A cada 6 meses (rotina).
- Apos alteracoes significativas na arquitetura.

Ultima revisao: 2026-08-14
Proxima revisao: 2027-02-14
