# UX-DESIGN.md

> Diretrizes de UX, design system e wireframes para o Sistema de Gestão Documental.
> Este documento garante consistência visual e experiencial entre todos os ecrãs.
> Última atualização: 2026-08-14

---

## 1. Filosofia de UX

### 1.1 Princípios Gerais

| Princípio | Descrição |
|-----------|-----------|
| **Rápido** | O utilizador não espera. Server Components por padrão, loading states claros, ações em <300ms. |
| **Óbvio** | Não há ecrãs de "como usar isto?". Se um contabilista precisa de formação para usar, falhámos. |
| **Tolerante a erros** | Upload falhou? Diz o quê e como corrigir. Documento rejeitado? Explica o porquê. |
| **Mobile-last para Admin, Mobile-first para Cliente** | Admin trabalha no desktop. Cliente acede pelo telemóvel. |
| **Densidade de informação adaptada** | Dashboard Admin = muita info, muitas colunas. Portal Cliente = pouca info, botões grandes. |

### 1.2 Personas e Contexto de Uso

| Persona | Dispositivo principal | Frequência | Estado de espírito | Prioridade |
|---------|----------------------|------------|-------------------|------------|
| **Admin (Owner)** | Desktop, 2 monitores | Diária, 4-6h | Pressa, multitasking | Eficiência |
| **Contabilista** | Desktop, laptop | Diária, 6-8h | Foco intenso, deadline | Velocidade |
| **Cliente** | Telemóvel (WhatsApp) | Mensal/bimestral | Impaciente, não quer estar aqui | Simplicidade |

---

## 2. Design System

### 2.1 Cores

Baseado no shadcn/ui com customização mínima. Não inventar paletas — usar o sistema de cores do shadcn (`slate`, `zinc`, etc.) com acentos funcionais.

```css
/* globals.css — @theme */
@theme {
  /* Base */
  --color-background: #ffffff;
  --color-foreground: #0f172a;       /* slate-900 */
  --color-muted: #f1f5f9;            /* slate-100 */
  --color-muted-foreground: #64748b; /* slate-500 */
  --color-border: #e2e8f0;           /* slate-200 */
  --color-ring: #3b82f6;             /* blue-500 */

  /* Primário — ação principal */
  --color-primary: #0f172a;          /* slate-900 */
  --color-primary-foreground: #ffffff;

  /* Secundário — ação secundária */
  --color-secondary: #f1f5f9;
  --color-secondary-foreground: #0f172a;

  /* Estados funcionais */
  --color-success: #22c55e;          /* green-500 — aprovado, ativo */
  --color-warning: #f59e0b;          /* amber-500 — pendente, aviso */
  --color-danger: #ef4444;           /* red-500 — rejeitado, erro, eliminar */
  --color-info: #3b82f6;             /* blue-500 — info, link */

  /* Portal Cliente — mais leve */
  --color-portal-primary: #2563eb;   /* blue-600 */
  --color-portal-bg: #f8fafc;        /* slate-50 */
}
```

### 2.2 Tipografia

| Elemento | Fonte | Tamanho | Peso | Nota |
|----------|-------|---------|------|------|
| Título página | Inter | 24px | 600 | `text-2xl font-semibold` |
| Título secção | Inter | 18px | 600 | `text-lg font-semibold` |
| Corpo | Inter | 14px | 400 | `text-sm` (padrão shadcn) |
| Legenda | Inter | 12px | 400 | `text-xs text-muted-foreground` |
| Botão primário | Inter | 14px | 500 | `text-sm font-medium` |
| Dado tabular | Inter | 13px | 400 | `text-[13px]` — densidade em tabelas |

**Regra:** Nunca usar fontes abaixo de 12px. Acessibilidade mínima.

### 2.3 Espaçamento e Layout

| Contexto | Padding | Gap | Nota |
|----------|---------|-----|------|
| Página dashboard | `p-6` (24px) | — | Conteúdo respiro |
| Card / Panel | `p-4` (16px) | — | Agrupamento de info |
| Tabela | `px-4 py-3` | — | Células com altura confortável |
| Formulário | `gap-4` (16px) | entre campos | Não amontoar inputs |
| Botões adjacentes | `gap-2` (8px) | — | Juntos mas não colados |
| Sidebar | `w-64` (256px) | — | Fixa, não colapsa em desktop |

### 2.4 Componentes Base (shadcn/ui)

Usar **sempre** componentes shadcn/ui. Não criar componentes customizados de input, botão, ou modal do zero.

| Componente | Uso | Customização |
|------------|-----|--------------|
| `Button` | Todas as ações | Variantes: `default`, `outline`, `ghost`, `destructive`. Tamanho: `sm` para tabelas, `default` para forms, `lg` para portal. |
| `Input` | Texto, email, número | Sempre com `label` acima. Nunca placeholder como label. |
| `Select` | Dropdowns | Com `placeholder` descritivo. |
| `Dialog` | Modais de confirmação | `max-w-lg` para forms, `max-w-2xl` para preview. |
| `Sheet` | Drawers laterais | Para filtros em mobile, detalhes em desktop. |
| `Table` | Listagens | Com `hover:bg-muted`, zebra não necessária. |
| `Badge` | Estados | Cores: `default` (ativo), `secondary` (arquivado), `destructive` (rejeitado/eliminado), `outline`+cor custom (pendente = amber). |
| `Toast` | Notificações | `success` para ações completas, `error` para falhas, `info` para avisos. |
| `Skeleton` | Loading | Sempre usar em vez de spinner circular genérico. |
| `Accordion` | Agrupar por ano | Documentos agrupados por ano no ecrã da empresa. |
| `Tabs` | Alternar vistas | Pouco usado, preferir sidebar navigation. |

---

## 3. Estrutura de Navegação

### 3.1 Dashboard (Admin + Contabilista)

```

  [Logo]  Empresas  Documentos  Utilizadores  Aprovações [] [Nome ] 
  
  Sidebar (w-64)      Conteúdo principal                      
                                            
   Dashboard                                              
   Empresas                                               
   Documentos                                             
   Utilizadores                                           
   Aprovações                                             
     [3]                                                  
   Auditoria                                              
                                              
   Configurações                                          
                                            

```

**Regras:**
- Sidebar sempre visível em desktop (`lg:` breakpoint)
- Em mobile: hamburger menu → sheet lateral
- Badge de notificações na sidebar (não no topo)
- Breadcrumb opcional (não obrigatório para MVP)

### 3.2 Portal do Cliente

```

  [Logo]                    [Sair]       
  
                                         
  Olá, [Nome]                            
                                         
  [Seletor de Empresa ]                 
                                         
  Documentos — [Nome da Empresa]         
                                         
  [Filtro: Todos ]  [Filtro: 2023 ]  
                                         
     
    Comparativo IVA 2023            
      15/03/2023    [Download ↓]      
     
                                         
     
    Extrato Bancário Jan/2023       
      02/02/2023    [Download ↓]      
     
                                         

```

**Regras:**
- Sem sidebar. Sem menus. Uma única página.
- Seletor de empresa em destaque se >1 empresa.
- Cards em vez de tabela (mais amigável em mobile).
- Botão de download grande e óbvio.
- Sem filtros complexos — dropdown simples.

---

## 4. Wireframes de Baixa Fidelidade

### 4.1 Login (Admin/Contabilista)

```

                                         
              [Logo]                     
                                         
         Aceder à Plataforma             
                                         
  Email                                  
     
   admin@consultoria.pt                
     
                                         
  Palavra-passe                          
     
   ••••••••••••••••••••              
     
                                         
  [        Entrar (loading...)      ]    
                                         
         Credenciais inválidas           
              (mensagem de erro)         
                                         

```

**Regras:**
- Centrado, card com `max-w-md`, sombra suave.
- Erro aparece abaixo do botão, em vermelho, com ícone.
- Loading no botão, não spinner genérico.
- Não lembrar palavra-passe (MVP — adicionar depois se necessário).

---

### 4.2 Lista de Empresas (Admin)

```

  [Sidebar]   Empresas                          [+ Empresa] 
              
              [ Procurar...        ] [Filtro ]        
              
              Nome          NIF        Docs    Ações       
              
              Empresa A     123456789   45     [] []  
              Empresa B     987654321   12     [] []  
              Empresa C     456789123    3     [] []  
              
              [< Anterior] Página 1 de 5 [Próxima >]     

```

**Regras:**
- Tabela com `hover:bg-muted`.
- Ações: ver (olho) → vai para documentos, editar (lápis) → modal.
- Botão "+ Empresa" sempre visível no topo direito.
- Filtro de procura com debounce (300ms).
- Número de documentos como badge/link.

---

### 4.3 Documentos da Empresa (Contabilista)

```

  [Sidebar]   Empresa A — Documentos          [+ Documento]
              
              [ Procurar...] [Tipo ] [Ano ] [Estado ]
              
               2023 (12 documentos)                       
                   
                  Comparativo IVA                      
                 Período: Dezembro  |  15/12/2023       
                 [Ativo]  [] [] []                 
                   
                   
                  Extrato Bancário                     
                 Período: Janeiro    |  02/01/2023       
                 [Ativo]  [] [] [ Submeter novo]   
                   
               2022 (8 documentos)                        
               2021 (3 documentos)                        

```

**Regras:**
- Agrupamento por ano (Accordion).
- Cada documento é um card com metadados claros.
- Estado como Badge colorido.
- Ações: visualizar (abre preview), download (signed URL), eliminar (soft delete, confirmação).
- "Submeter novo" aparece apenas se já existe documento do mesmo tipo/período (fluxo de substituição).

---

### 4.4 Upload de Documento (Modal)

```

  Carregar Documento                [×]  
  
                                         
  Empresa *                              
     
   Empresa A                           
     
                                         
  Tipo de documento *                    
     
   Comparativo IVA                     
     
                                         
  Ano *        Período                   
           
   2023       Dezembro               
           
                                         
  Ficheiro *                             
     
   [] Arraste ou clique para         
        selecionar (PDF, JPG, PNG)     
     
  comparativo_iva_dez_2023.pdf (2.4MB)   
  [] 80%               
                                         
  Notas (opcional)                       
     
                                       
     
                                         
  [      Carregar (a enviar...)     ]    
                                         

```

**Regras:**
- Modal `max-w-lg`.
- Campos obrigatórios marcados com `*`.
- Dropzone para ficheiro com drag-and-drop.
- Progresso de upload em tempo real (fetch com progress).
- Preview do ficheiro selecionado (nome + tamanho).
- Se já existe documento do mesmo tipo/ano/período: aviso "Este documento irá substituir a versão atual e ficará pendente de aprovação."

---

### 4.5 Aprovações Pendentes (Admin)

```

  [Sidebar]   Aprovações Pendentes              [3]        
              
                   
                Comparativo IVA — Empresa A            
               Submetido por: Maria | 14/08 15:32        
               Substitui: Comparativo IVA Dez 2023       
                                                         
               [ Preview]  [ Aprovar]  [ Rejeitar]  
                   
                   
                Relatório IRS — Empresa B              
               Submetido por: João  | 14/08 14:10        
                                                         
               [ Preview]  [ Aprovar]  [ Rejeitar]  
                   

```

**Regras:**
- Cards verticais, não tabela — cada aprovação precisa de atenção.
- Preview em modal (iframe do PDF).
- Aprovar/Rejeitar com confirmação (Dialog).
- Rejeitar: campo opcional de motivo.
- Após ação, card desaparece com animação suave.

---

### 4.6 Portal do Cliente — Login

```

                                         
           [Logo da Consultoria]         
                                         
         Portal do Cliente               
                                         
  Número de telemóvel                    
     
   351 912 345 678                     
     
                                         
  [  Receber código no WhatsApp  ]       
                                         
    ou                   
                                         
  Código de acesso                       
       
   4    2    9    1    7    3  
       
                                         
  [           Entrar            ]        
                                         
  Código expira em 09:32                 
  [Reenviar código]                      
                                         

```

**Regras:**
- Fundo `bg-portal-bg` (slate-50), mais leve que o dashboard.
- Input de telemóvel com máscara automática.
- Código em 6 caixas separadas (auto-focus no próximo).
- Contagem decrescente visível.
- "Reenviar código" desabilitado por 60 segundos.
- Teclado numérico no mobile (`inputMode="numeric"`).
- Erro: toast vermelho, não alert nativo.

---

### 4.7 Portal do Cliente — Documentos

```

  [Logo]                    [Sair]       
  
                                         
  Olá, António Silva                     
                                         
     
    Selecionar empresa               
    Empresa A, Lda.                  
     
                                         
  Documentos — Empresa A                 
                                         
  [Todos ]  [2023 ]                  
                                         
     
    Comparativo IVA                 
   Dezembro 2023                      
   15/12/2023                         
                                      
      [   Download  ]                
     
                                         
     
    Extrato Bancário                
   Janeiro 2023                       
   02/01/2023                         
                                      
      [   Download  ]                
     
                                         
  Nenhum documento para 2022             
                                         

```

**Regras:**
- Cards grandes, fáceis de tocar (min-height 120px).
- Botão de download é a ação principal — verde, grande, óbvio.
- Sem estados, sem badges, sem informação técnica.
- Se >1 empresa: seletor em destaque no topo.
- Se 1 empresa: seletor escondido, mostra diretamente.
- Empty state amigável: "Ainda não há documentos para este período." (não "0 results").

---

## 5. Estados e Feedback

### 5.1 Loading States

| Contexto | Componente | Duração esperada |
|----------|-----------|------------------|
| Página inicial | Skeleton de tabela/cards | <500ms |
| Submit formulário | Button com `disabled` + spinner | <2s |
| Upload de ficheiro | Barra de progresso + percentagem | Variável |
| Geração de signed URL | Button loading | <300ms |
| Download | Button brief loading | <1s |
| Aprovação | Card fade-out após ação | Animação 300ms |

**Regra:** Nunca deixar o utilizador sem feedback visual. Se uma ação demora >300ms, mostrar loading.

### 5.2 Estados Vazios

| Contexto | Mensagem | Ação |
|----------|----------|------|
| Sem empresas | "Ainda não há empresas registadas." | Botão "Adicionar primeira empresa" |
| Sem documentos | "Ainda não há documentos para esta empresa." | Botão "Carregar primeiro documento" |
| Sem aprovações pendentes | "Não há documentos pendentes de aprovação. " | — |
| Sem resultados de pesquisa | "Nenhum resultado para 'xxx'." | Link "Limpar filtros" |
| Portal sem docs | "A sua consultoria ainda não disponibilizou documentos." | — |

**Regra:** Sempre oferecer uma ação no empty state. Nunca deixar o utilizador num beco sem saída.

### 5.3 Estados de Erro

| Erro | Mensagem | Ação |
|------|----------|------|
| Login falhou | "Email ou palavra-passe incorretos." | — |
| Sem permissão | "Não tem permissão para aceder a esta página." | Link para dashboard |
| Upload falhou | "Não foi possível carregar o ficheiro. Tente novamente." | Botão "Tentar de novo" |
| OTP inválido | "Código incorreto. Tem X tentativas restantes." | — |
| OTP expirado | "Código expirado. Peça um novo código." | Botão "Reenviar" |
| Sessão expirada | "A sua sessão expirou. Por favor, entre novamente." | Redirect para login |

**Regra:** Mensagens em português, diretas, sem jargon técnico. "Erro 500" → "Algo correu mal. Tente novamente."

---

## 6. Responsividade

### 6.1 Breakpoints

| Breakpoint | Largura | Layout |
|-----------|---------|--------|
| Mobile | < 768px | Portal: stacked cards. Dashboard: hamburger menu, tabela scroll horizontal. |
| Tablet | 768px - 1024px | Dashboard: sidebar colapsável. Tabelas com menos colunas visíveis. |
| Desktop | > 1024px | Sidebar fixa. Tabelas completas. Modais centrados. |

### 6.2 Regras Mobile

- **Dashboard:** Tabelas com scroll horizontal (nunca esconder colunas sem alternativa).
- **Portal:** Cards full-width, botões touch-friendly (min-height 48px).
- **Teclado:** Inputs numéricos usam `inputMode="numeric"` (teclado numérico no mobile).
- **Touch:** Ações de swipe não no MVP (tap simples).

---

## 7. Acessibilidade (Mínimo Viável)

- [ ] Todos os inputs têm `label` associado (nunca placeholder como label).
- [ ] Botões e links têm `aria-label` quando o texto não é auto-explicativo.
- [ ] Cores não são o único indicador de estado (badge de "rejeitado" tem texto + cor).
- [ ] Contraste mínimo 4.5:1 para texto (sistema shadcn já garante isto).
- [ ] Focus visible em todos os elementos interativos.
- [ ] Modal fecha com `Escape`.

---

## 8. Animações e Micro-interações

| Interação | Animação | Duração |
|-----------|----------|---------|
| Abrir modal | Fade + scale(0.95 → 1) | 150ms |
| Fechar modal | Fade + scale(1 → 0.95) | 100ms |
| Aprovar documento | Card slide-out para direita + fade | 300ms |
| Rejeitar documento | Card slide-out para esquerda + fade | 300ms |
| Toast aparecer | Slide de cima + fade | 200ms |
| Toast desaparecer | Fade | 200ms |
| Loading skeleton | Shimmer pulse | 1.5s loop |
| Hover em tabela | `bg-muted` transition | 100ms |

**Regra:** Animações são `ease-out`, nunca `linear`. Não usar animações em preferências de movimento reduzido (`prefers-reduced-motion`).

---

## 9. Checklist de UX por Tarefa

Antes de marcar qualquer tarefa de frontend como `DONE`, verificar:

- [ ] Todos os estados (loading, empty, error, success) estão tratados?
- [ ] O utilizador sabe sempre onde está (título da página claro)?
- [ ] Ações destrutivas (eliminar, rejeitar) têm confirmação?
- [ ] Formulários têm validação em tempo real?
- [ ] Mobile: todos os botões são tocáveis (min 44x44px)?
- [ ] Feedback visual em <300ms para qualquer ação?
- [ ] Textos estão em português, sem jargon técnico?
- [ ] Empty states têm uma ação clara?
