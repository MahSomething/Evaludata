# MVP-SCOPE.md

> Documento de scope minimo viavel para o sistema de gestao documental de consultorias de contabilidade.
> Atualizacao: 2026-08-15

---

## 1. Visao Geral

Sistema de gestao documental multi-tenant para consultorias de contabilidade em Mocambique, com hierarquia de permissoes, fluxo de aprovacao de documentos e portal do cliente.

**Regra de ouro:** Se uma funcionalidade nao estiver listada em "O que ENTRA", nao e construida agora. Nao ha excecoes.

---

## 2. O que ENTRA (Must Have)

### 2.1 Hierarquia de Utilizadores

| Role | Descricao | Quem cria |
|------|-----------|-----------|
| **Super Admin** | Administrador do sistema. Acesso total. | Manual (seed) |
| **Admin (Owner)** | Gestor/proprietario da consultoria. Gerencia a sua organizacao. | Super Admin |
| **Contabilista** | Colaborador da consultoria. Faz upload de documentos. | Admin |
| **Cliente** | Representante legal/proprietario das empresas assistidas. Apenas visualiza. | Admin (se a consultoria tiver permissao) ou Super Admin |

### 2.2 Funcionalidades por Role

#### Super Admin
- Criar consultorias (`organizacoes`)
- Designar Owner de cada consultoria
- Ativar/desativar permissao "pode_registar_clientes" por consultoria
- Ver todas as organizacoes e dados (read-only por padrao, exceto gestao)

#### Admin (Owner da Consultoria)
- Criar/editar empresas (clientes da contabilidade)
- Criar/editar contabilistas
- Atribuir empresas aos contabilistas (matriz de acesso)
- Criar/editar clientes (se `pode_registar_clientes = true`)
- Atribuir empresas aos clientes
- Aprovar ou rejeitar novas versoes de documentos pendentes
- Ver todos os documentos da sua organizacao

#### Contabilista
- Ver apenas empresas que lhe foram atribuidas
- Fazer upload de documentos para empresas atribuidas
- Submeter nova versao de documento (fica pendente de aprovacao)
- Editar metadados de documentos que criou (tipo, ano, notas) — sem aprovacao
- **NAO pode remover documentos**
- **NAO pode criar empresas ou clientes**

#### Cliente
- Login via OTP WhatsApp (6 digitos, expira em 10 min, max 3 tentativas)
- Ver lista de empresas a si atribuidas (seletor/aba)
- Ver e fazer download de documentos "ativos" das suas empresas
- **NAO pode upload, editar ou remover**

### 2.3 Gestao de Documentos

- Upload de PDF/imagem para empresa + tipo de documento + ano/periodo
- Campos: `tipo_documento`, `ano`, `periodo` (opcional, ex: "Q1", "Janeiro"), `notas`, `metadados` (JSONB flexivel)
- Ficheiros armazenados em R2 (Cloudflare) via Supabase Storage ou upload direto
- Registo em base de dados com URL, nome original, tamanho
- **Versionamento com aprovacao:**
  - Contabilista carrega nova versao → estado `pendente`
  - Versao anterior mantem-se `ativo`
  - Admin aprova → nova versao fica `ativo`, anterior fica `arquivado`
  - Admin rejeita → nova versao fica `rejeitado`, anterior mantem `ativo`
- **Eliminacao (soft delete):**
  - Admin ou sistema marca como `eliminado`
  - Documento fica invisivel na UI
  - Apos 90 dias, eliminacao fisica automatica (ficheiro + registo)
  - Documentos `rejeitados` seguem a mesma regra de 90 dias

### 2.4 Pesquisa e Listagem

- Lista de empresas com filtros: nome, NUIT
- Pagina da empresa → lista de documentos agrupados por ano
- Filtros de documentos: tipo, ano, periodo, estado
- Pesquisa simples no topo (por nome da empresa, NUIT, tipo de documento)
- **Sem pesquisa full-text dentro do conteudo do PDF**

### 2.5 Auditoria

- Tabela `log_acessos` regista: quem, que documento, que acao (visualizou, transferiu, aprovou, rejeitou), IP, user-agent, timestamp
- Visivel apenas para Admin e Super Admin

### 2.6 Portal do Cliente

- Rota separada: `/portal`
- UI minimalista: seletor de empresas → lista de documentos ativos → visualizacao/download
- Sem menus laterais, sem filtros complexos, sem upload
- Autenticacao via OTP WhatsApp (nao magic link)

---

## 3. O que FICA FORA (Explicitamente Nao)

| Funcionalidade | Porque fora |
|----------------|-------------|
| **OCR** (qualquer tipo) | Complexidade desproporcionada para o MVP. Metadados manuais + nome do ficheiro resolvem 80% da dor. |
| **Pesquisa full-text dentro de PDFs** | Depende de OCR ou indexacao de PDFs nativos. Fase 2. |
| **Notificacoes automaticas** (email, push) | Badge na UI e lista de pendentes basta para o MVP. |
| **Alertas de expiracao/retencao** | Campo `ano` visivel e correto e suficiente agora. |
| **Billing / planos / self-service** | Multi-tenant existe, mas onboarding e manual pelo Super Admin. |
| **Edicao inline de PDFs** | Fora de scope. Substituicao por upload e o fluxo. |
| **Mobile app / PWA** | Portal responsivo e suficiente. |
| **Dashboards e relatorios** | Listas com filtros sao suficientes. |
| **Integracao com sistemas externos** (AT, bancos, etc.) | Nao no MVP. |

---

## 4. Criterio de "Pronto"

O MVP esta pronto quando:

1. Um **Admin** consegue criar uma empresa, um contabilista e atribuir acesso em menos de 2 minutos.
2. Um **Contabilista** consegue fazer upload de um documento e o Admin ve o pendente para aprovacao.
3. Um **Cliente** recebe OTP no WhatsApp, entra no portal e ve os documentos da(s) sua(s) empresa(s) em menos de 30 segundos.
4. Um **Super Admin** consegue criar uma nova consultoria e designar um Owner.
5. Um documento **rejeitado ou eliminado** desaparece da UI normal mas permanece acessivel para auditoria por 90 dias.
6. **Nenhum utilizador ve dados de outra organizacao** — RLS validado em todas as tabelas.

---

## 5. Stack Fixa (Nao Negociavel)

| Tecnologia | Versao / Nota |
|------------|---------------|
| Next.js | 16.x (App Router, Turbopack) |
| React | 19.x |
| Node.js | 22 LTS |
| Tailwind CSS | v4 (configuracao em `globals.css`, **nunca** `tailwind.config.js`) |
| shadcn/ui | via CLI `npx shadcn@latest add [componente]` |
| Supabase | Postgres + Auth + Storage |
| Supabase SSR | `@supabase/ssr` (3 clientes: browser, server, proxy) |
| Cloudflare R2 | Storage de ficheiros |
| Zod | Validacao de schemas |
| React Hook Form | Formularios com validacao |

---

## 6. Notas sobre Retencao de 90 Dias

- Documentos com `estado = 'rejeitado'` ou `estado = 'eliminado'` tem `data_soft_delete` preenchida.
- Um job periodico (Supabase Edge Function ou cron externo) verifica diariamente: `data_soft_delete < NOW() - INTERVAL '90 days'`.
- Ao expirar: elimina ficheiro do storage e registo da base de dados.
- Durante os 90 dias: visiveis apenas em painel de auditoria/reciclagem (Admin/Super Admin).
