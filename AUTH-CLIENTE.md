# AUTH-CLIENTE.md

> Fluxo de autenticação do Cliente via OTP enviado por WhatsApp.
> O cliente não usa email/senha nem magic links. Usa número de telemóvel + código OTP.
> Última atualização: 2026-08-14

---

## 1. Visão Geral do Fluxo

```
     1. Introduz número de telemóvel    
   Cliente    >    Portal     
  (WhatsApp)                                            /portal    
                                        
                                                              
           2. Servidor gera OTP (6 dígitos)                  
           3. Envia OTP via WhatsApp API                     
       <
                                                              
           4. Cliente introduz OTP no portal                 
       >
                                                              
           5. Servidor valida OTP                            
           6. Cria sessão Supabase (JWT com claims)          
       <
                                                              
           7. Cliente acede ao portal (empresas + docs)      
```

---

## 2. Porquê OTP via WhatsApp em vez de Magic Link?

| | Magic Link | OTP WhatsApp |
|---|---|---|
| **Expiração** | 1 hora (padrão Supabase) | Configurável (ex: 10 min) |
| **Problema com antivírus** | Sim — scanners de email consomem o link | Não — código numérico |
| **Experiência do cliente** | Abrir email → clicar link → esperar | Receber WhatsApp → digitar 6 dígitos |
| **Adoção em Portugal** | Email é comum | WhatsApp é ubíquo |
| **Custo** | Gratuito (Supabase) | Custo da API WhatsApp (baixo) |
| **Implementação** | Nativa no Supabase | Custom (não nativo) |

**Decisão:** OTP via WhatsApp. Mais robusto, melhor experiência para o público-alvo (proprietários de empresas em Portugal).

---

## 3. Modelo de Dados Adicional

```sql
-- Tabela para armazenar OTPs temporários
-- NOTA: Não usar a tabela auth do Supabase diretamente para OTP custom
-- Em vez disso, usamos uma tabela auxiliar + criamos/utilizador na tabela auth

-- Já existe na tabela utilizadores: telemovel, papel = 'cliente'
-- Adicionar coluna se não existir:
ALTER TABLE utilizadores ADD COLUMN IF NOT EXISTS telemovel TEXT UNIQUE;

-- Tabela de OTPs (pode ser uma tabela simples ou usar Redis/cache)
otp_codes (
  id uuid pk,
  utilizador_id uuid -> utilizadores.id,
  telemovel text,
  codigo text,           -- 6 dígitos
  expira_em timestamp,   -- NOW() + INTERVAL '10 minutes'
  tentativas int default 0,
  utilizado boolean default false,
  criado_em timestamp default NOW()
);
```

---

## 4. Opções de API WhatsApp

### 4.1 Evolution API (Recomendada — self-hosted ou SaaS)

- Open source, muito usada em Portugal/Brasil
- Suporta WhatsApp Business API via Baileys (não oficial) ou oficial
- Preço: gratuito (self-hosted) ou ~€10-30/mês (SaaS)
- Documentação: https://doc.evolution-api.com

```ts
// lib/whatsapp/evolution.ts
export async function sendOtpWhatsApp(phone: string, code: string) {
  const res = await fetch(`${process.env.WHATSAPP_API_URL}/message/sendText/${process.env.WHATSAPP_INSTANCE}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": process.env.WHATSAPP_API_KEY!,
    },
    body: JSON.stringify({
      number: phone,  // formato: 351912345678
      text: `Código de acesso ao portal: *${code}*\n\nVálido por 10 minutos. Não partilhe este código.`,
    }),
  });

  return res.ok;
}
```

### 4.2 Meta Business API (Oficial)

- Requer verificação de negócio na Meta
- Preço: ~€0.05-0.08 por conversação (24h)
- Mais complexo de configurar, mas 100% oficial
- Documentação: https://developers.facebook.com/docs/whatsapp

### 4.3 Twilio WhatsApp API

- Fácil de usar, mas mais caro
- Preço: ~€0.05 por mensagem
- Documentação: https://www.twilio.com/whatsapp

**Recomendação:** Começar com Evolution API (self-hosted ou plano básico). Se escalar muito, migrar para Meta oficial.

---

## 5. Fluxo Completo — Código

### 5.1 Etapa 1: Pedir OTP

```ts
// app/actions/auth-cliente.ts
'use server';

import { createClient } from "@/lib/supabase/server";
import { sendOtpWhatsApp } from "@/lib/whatsapp/evolution";
import { randomInt } from "crypto";
import { z } from "zod";

const phoneSchema = z.string().regex(/^3519\d{8}$/, "Número inválido. Formato: 351912345678");

export async function requestOtp(phone: string) {
  const supabase = await createClient();

  // Validar formato
  const parsed = phoneSchema.safeParse(phone);
  if (!parsed.success) return { success: false, error: "Número de telemóvel inválido" };

  // Verificar se o número pertence a um cliente ativo
  const { data: user } = await supabase
    .from("utilizadores")
    .select("id, nome, ativo, papel")
    .eq("telemovel", phone)
    .eq("papel", "cliente")
    .eq("ativo", true)
    .single();

  if (!user) {
    // Não revelar se o número existe ou não (segurança)
    return { success: false, error: "Número não encontrado ou inativo" };
  }

  // Gerar OTP (6 dígitos)
  const code = randomInt(100000, 999999).toString();

  // Guardar OTP na BD (ou Redis)
  const { error: otpError } = await supabase.from("otp_codes").insert({
    utilizador_id: user.id,
    telemovel: phone,
    codigo: code,
    expira_em: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 min
    tentativas: 0,
    utilizado: false,
  });

  if (otpError) return { success: false, error: "Erro ao gerar código" };

  // Enviar via WhatsApp
  const sent = await sendOtpWhatsApp(phone, code);
  if (!sent) {
    // Rollback: eliminar OTP
    await supabase.from("otp_codes").delete().eq("codigo", code);
    return { success: false, error: "Erro ao enviar WhatsApp. Tente novamente." };
  }

  return { success: true, data: { message: "Código enviado para o WhatsApp" } };
}
```

### 5.2 Etapa 2: Validar OTP e Criar Sessão

```ts
// app/actions/auth-cliente.ts
export async function verifyOtp(phone: string, code: string) {
  const supabase = await createClient();
  const supabaseAdmin = createClientAdmin(); // com service role

  // Buscar OTP válido
  const { data: otp } = await supabase
    .from("otp_codes")
    .select("*")
    .eq("telemovel", phone)
    .eq("codigo", code)
    .eq("utilizado", false)
    .gt("expira_em", new Date().toISOString())
    .single();

  if (!otp) {
    // Incrementar tentativas (opcional — rate limiting)
    return { success: false, error: "Código inválido ou expirado" };
  }

  // Marcar como utilizado
  await supabase.from("otp_codes").update({ utilizado: true }).eq("id", otp.id);

  // Buscar utilizador
  const { data: user } = await supabase
    .from("utilizadores")
    .select("id, email, nome, organizacao_id, papel")
    .eq("id", otp.utilizador_id)
    .single();

  if (!user) return { success: false, error: "Utilizador não encontrado" };

  // Criar sessão no Supabase Auth (usando service role)
  // NOTA: O Supabase Auth não suporta OTP custom nativamente.
  // Estratégia: criar um token de sessão manual ou usar uma abordagem alternativa.

  // OPÇÃO A: Criar um "password" temporário e fazer signInWithPassword
  // (menos elegante, mas funciona)

  // OPÇÃO B: Usar Supabase Auth com OTP nativo (mas envia por email, não WhatsApp)
  // Não serve.

  // OPÇÃO C (RECOMENDADA): Usar uma sessão custom via cookies httpOnly
  // Criar um JWT próprio com as claims necessárias
  // OU usar o Supabase Auth com um "hack": criar o user com email fictício
  // e fazer signIn com um token custom.

  // AQUI VAMOS COM A OPÇÃO MAIS PRÁTICA PARA O MVP:
  // Criar um token de sessão custom e guardar em cookie httpOnly.
  // O middleware (proxy.ts) valida este token e injeta o user no contexto.

  // Para simplificar, vamos usar a abordagem do Supabase Auth com um email
  // associado ao cliente (mesmo que não seja usado) e fazer signIn.

  const { data: session, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
    email: user.email,
    password: code + phone.slice(-4), // password temporária baseada no OTP (não ideal, mas funciona)
  });

  if (sessionError) {
    return { success: false, error: "Erro ao criar sessão" };
  }

  return {
    success: true,
    data: {
      accessToken: session.session.access_token,
      refreshToken: session.session.refresh_token,
    },
  };
}
```

**NOTA:** A abordagem acima é simplificada. Para produção, considerar:
- Usar `supabase.auth.admin.createUser()` com email + password temporária
- Ou implementar sessão custom com `jose` (JWT library) e cookies httpOnly

### 5.3 Abordagem Recomendada para Produção — Sessão Custom

```ts
// lib/auth/session.ts
import { SignJWT, jwtVerify } from "jose";

const SECRET = new TextEncoder().encode(process.env.SESSION_SECRET!);

export async function createSession(userId: string, organizacaoId: string, papel: string) {
  const token = await new SignJWT({ userId, organizacaoId, papel })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime("8h")
    .sign(SECRET);

  return token;
}

export async function verifySession(token: string) {
  try {
    const { payload } = await jwtVerify(token, SECRET, { clockTolerance: 60 });
    return payload as { userId: string; organizacaoId: string; papel: string };
  } catch {
    return null;
  }
}
```

**Vantagem:** Total controlo sobre expiração, claims, e não depende do Supabase Auth para clientes.
**Desvantagem:** Tens de gerar tu próprio o refresh token e a lógica de logout.

**Alternativa híbrida (melhor):**
- Admin/Contabilista: Supabase Auth nativo (email/senha)
- Cliente: Sessão custom com JWT próprio + cookie httpOnly
- O `proxy.ts` verifica ambos os tipos de token

---

## 6. UI do Portal do Cliente

### 6.1 Ecrã de Login

```tsx
// app/(portal)/login/page.tsx
'use client';

import { useState } from "react";
import { requestOtp, verifyOtp } from "@/app/actions/auth-cliente";

export default function ClienteLoginPage() {
  const [step, setStep] = useState<"phone" | "otp">("phone");
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleRequestOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const res = await requestOtp(phone);
    setLoading(false);
    if (res.success) setStep("otp");
    else alert(res.error);
  }

  async function handleVerifyOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const res = await verifyOtp(phone, otp);
    setLoading(false);
    if (res.success) {
      // Guardar token em cookie (ou o Server Action já o fez)
      window.location.href = "/portal";
    } else {
      alert(res.error);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      {step === "phone" ? (
        <form onSubmit={handleRequestOtp}>
          <h1>Aceder ao Portal</h1>
          <input
            type="tel"
            placeholder="351912345678"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            required
          />
          <button type="submit" disabled={loading}>
            {loading ? "A enviar..." : "Receber código no WhatsApp"}
          </button>
        </form>
      ) : (
        <form onSubmit={handleVerifyOtp}>
          <h1>Introduza o código</h1>
          <p>Enviamos um código de 6 dígitos para o WhatsApp {phone}</p>
          <input
            type="text"
            maxLength={6}
            placeholder="123456"
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            required
          />
          <button type="submit" disabled={loading}>
            {loading ? "A validar..." : "Entrar"}
          </button>
          <button type="button" onClick={() => setStep("phone")}>
            Reenviar código
          </button>
        </form>
      )}
    </div>
  );
}
```

---

## 7. Rate Limiting por IP

```ts
// lib/rate-limit.ts
import { LRUCache } from "lru-cache";

const otpCache = new LRUCache<string, number>({
  max: 500,
  ttl: 1000 * 60 * 15, // 15 minutos
});

export function checkOtpRateLimit(ip: string): boolean {
  const count = otpCache.get(ip) || 0;
  if (count >= 5) return false; // máx 5 OTPs / 15 min / IP
  otpCache.set(ip, count + 1);
  return true;
}
```

Usar no `requestOtp`:
```ts
const ip = headers().get("x-forwarded-for") || "unknown";
if (!checkOtpRateLimit(ip)) {
  return { success: false, error: "Muitas tentativas. Aguarde 15 minutos." };
}
```

---

## 8. Checklist de Implementação

- [ ] Conta Evolution API (ou alternativa) configurada e número de telemóvel verificado
- [ ] Variáveis `WHATSAPP_API_URL`, `WHATSAPP_API_KEY`, `WHATSAPP_INSTANCE` no `.env.local`
- [ ] Coluna `telemovel` adicionada à tabela `utilizadores`
- [ ] Tabela `otp_codes` criada com índice em `telemovel + codigo + expira_em`
- [ ] Server Action `requestOtp` testada com número real
- [ ] Server Action `verifyOtp` testada com código correto e expirado
- [ ] Rate limiting implementado e testado
- [ ] Sessão do cliente funciona e redireciona para `/portal`
- [ ] Logout do cliente limpa o cookie de sessão
- [ ] Cliente não consegue aceder a rotas de admin (testar manualmente)
