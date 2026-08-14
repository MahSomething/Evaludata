# MVP-SCOPE.md

> Documento de scope mínimo viável para o sistema de gestão documental de consultorias de contabilidade.
> Última atualização: 2026-08-14

---

## 1. Visão Geral

Sistema de gestão documental multi-tenant para consultorias de contabilidade, com hierarquia de permissões, fluxo de aprovação de documentos e portal do cliente.

**Regra de ouro:** Se uma funcionalidade não estiver listada em "O que ENTRA", não é construída agora. Não há exceções.

---

## 2. O que ENTRA (Must Have)

### 2.1 Hierarquia de Utilizadores

| Role | Descrição | Quem cria |
|------|-----------|-----------|
| **Super Admin** | Administrador do sistema. Acesso total. | Manual (seed) |
| **Admin (Owner)** | Gestor/proprietário da consultoria. Gerencia a sua organização. | Super Admin |
| **Contabilista** | Colaborador da consultoria. Faz upload de documentos. | Admin |
| **Cliente** | Representante legal/proprietário das empresas assistidas. Apenas visualiza. | Admin (se a consultoria tiver permissão) ou Super Admin |

### 2.2 Funcionalidades por Role

#### Super Admin
- Criar consultorias (`organizacoes`)
- Designar Owner de cada consultoria
- Ativar/desativar permissão "pode_registar_clientes" por consultoria
- Ver todas as organizações e dados (read-only por padrão, exceto gestão)

#### Admin (Owner da Consultoria)
- Criar/editar empresas (clientes da contabilidade)
- Criar/editar contabilistas
- Atribuir empresas aos contabilistas (matriz de acesso)
- Criar/editar clientes (se `pode_registar_clientes = true`)
- Atribuir empresas aos clientes
- Aprovar ou rejeitar novas versões de documentos pendentes
- Ver todos os documentos da sua organização

#### Contabilista
- Ver apenas empresas que lhe foram atribuídas
- Fazer upload de documentos para empresas atribuídas
- Submeter nova versão de documento (fica pendente de aprovação)
- Editar metadados de documentos que criou (tipo, ano, notas) — sem aprovação
- **NÃO pode remover documentos**
- **NÃO pode criar empresas ou clientes**

#### Cliente
- Login via magic link (experiência simplificada)
- Ver lista de empresas a si atribuídas (seletor/aba)
- Ver e fazer download de documentos "ativos" das suas empresas
- **NÃO pode upload, editar ou remover**

### 2.3 Gestão de Documentos

- Upload de PDF/imagem para empresa + tipo de documento + ano/período
- Campos: `tipo_documento`, `ano`, `periodo` (opcional, ex: "Q1", "Janeiro"), `notas`, `metadados` (JSONB flexível)
- Ficheiros armazenados em R2 (Cloudflare) via Supabase Storage ou upload direto
- Registo em base de dados com URL, nome original, tamanho
- **Versionamento com aprovação:**
  - Contabilista carrega nova versão → estado `pendente`
  - Versão anterior mantém-se `ativo`
  - Admin aprova → nova versão fica `ativo`, anterior fica `arquivado`
  - Admin rejeita → nova versão fica `rejeitado`, anterior mantém-se `ativo`
- **Eliminação (soft delete):**
  - Admin ou sistema marca como `eliminado`
  - Documento fica invisível na UI
  - Após 90 dias, eliminação física automática (ficheiro + registo)
  - Documentos `rejeitados` seguem a mesma regra de 90 dias

### 2.4 Pesquisa e Listagem

- Lista de empresas com filtros: nome, NUIT
- Página da empresa → lista de documentos agrupados por ano
- Filtros de documentos: tipo, ano, período, estado
- Pesquisa simples no topo (por nome da empresa, NUIT, tipo de documento)
- **Sem pesquisa full-text dentro do conteúdo do PDF**

### 2.5 Auditoria

- Tabela `log_acessos` registra: quem, que documento, que ação (visualizou, transferiu, aprovou, rejeitou), IP, user-agent, timestamp
- Visível apenas para Admin e Super Admin

### 2.6 Portal do Cliente

- Rota separada: `/portal` ou `/cliente`
- UI minimalista: seletor de empresas → lista de documentos ativos → visualização/download
- Sem menus laterais, sem filtros complexos, sem upload

---

## 3. O que FICA FORA (Explicitamente Não)

| Funcionalidade | Porquê fora |
|----------------|-------------|
| **OCR** (qualquer tipo) | Complexidade desproporcionada para o MVP. Metadados manuais + nome do ficheiro resolvem 80% da dor. |
| **Pesquisa full-text dentro de PDFs** | Depende de OCR ou indexação de PDFs nativos. Fase 2. |
| **Notificações automáticas** (email, push) | Badge na UI e lista de pendentes basta para o MVP. |
| **Alertas de expiração/retenção** | Campo `ano` visível e correto é suficiente agora. |
| **Billing / planos / self-service** | Multi-tenant existe, mas onboarding é manual pelo Super Admin. |
| **Edição inline de PDFs** | Fora de scope. Substituição por upload é o fluxo. |
| **Mobile app / PWA** | Portal responsivo é suficiente. |
| **Dashboards e relatórios** | Listas com filtros são suficientes. |
| **Integração com sistemas externos** (AT, bancos, etc.) | Não no MVP. |

---

## 4. Critério de "Pronto"

O MVP está pronto quando:

1. Um **Admin** consegue criar uma empresa, um contabilista e atribuir acesso em menos de 2 minutos.
2. Um **Contabilista** consegue fazer upload de um documento e o Admin vê o pendente para aprovação.
3. Um **Cliente** recebe magic link, entra no portal e vê os documentos da(s) sua(s) empresa(s) em menos de 30 segundos.
4. Um **Super Admin** consegue criar uma nova consultoria e designar um Owner.
5. Um documento **rejeitado ou eliminado** desaparece da UI normal mas permanece acessível para auditoria por 90 dias.
6. **Nenhum utilizador vê dados de outra organização** — RLS validado em todas as tabelas.

---

## 5. Stack Fixa (Não Negociável)

| Tecnologia | Versão / Nota |
|------------|---------------|
| Next.js | 16.x (App Router, Turbopack) |
| React | 19.x |
| Node.js | 22 LTS |
| Tailwind CSS | v4 (configuração em `globals.css`, **nunca** `tailwind.config.js`) |
| shadcn/ui | via CLI `npx shadcn@latest add [componente]` |
| Supabase | Postgres + Auth + Storage |
| Supabase SSR | `@supabase/ssr` (3 clientes: browser, server, proxy) |
| Cloudflare R2 | Storage de ficheiros (ou Supabase Storage como alternativa imediata) |
| Variáveis de ambiente | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (ou `PUBLISHABLE_KEY`), `SUPABASE_SERVICE_ROLE_KEY` |

---

## 6. Notas sobre Retenção de 90 Dias

- Documentos com `estado = 'rejeitado'` ou `estado = 'eliminado'` têm `data_soft_delete` preenchida.
- Um job periódico (Supabase Edge Function ou cron externo) verifica diariamente: `data_soft_delete < NOW() - INTERVAL '90 days'`.
- Ao expirar: elimina ficheiro do storage e registo da base de dados.
- Durante os 90 dias: visíveis apenas em painel de auditoria/reciclagem (Admin/Super Admin).
