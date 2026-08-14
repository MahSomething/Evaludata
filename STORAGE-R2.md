# STORAGE-R2.md

> Arquitetura de storage de ficheiros usando Cloudflare R2 com Signed URLs.
> Objetivo: evitar custos de egress no Supabase Storage e suportar ficheiros grandes (> 1MB).
> Última atualização: 2026-08-14

---

## 1. Porquê R2 em vez de Supabase Storage?

| | Supabase Storage | Cloudflare R2 |
|---|---|---|
| **Egress** (transferência para fora) | $0.09/GB | **$0** (gratuito) |
| **Storage** | $0.021/GB/mês | $0.015/GB/mês |
| **Signed URLs** | Automático, integrado com RLS | Manual (S3 SDK) |
| **CDN** | Sim | Sim (Cloudflare edge) |
| **Complexidade** | Baixa | Média |

**Decisão:** Usar R2 como storage principal. O Supabase fica apenas para base de dados e auth.

---

## 2. Variáveis de Ambiente

```env
# .env.local (servidor)
R2_ACCOUNT_ID=seu-account-id
R2_ACCESS_KEY_ID=seu-access-key
R2_SECRET_ACCESS_KEY=seu-secret-key
R2_BUCKET_NAME=documentos-consultoria
R2_PUBLIC_URL=https://pub-xxx.r2.dev  # URL pública do bucket (se quiser acesso direto)
R2_ENDPOINT=https://seu-account-id.r2.cloudflarestorage.com

# .env.local (cliente — nenhuma, tudo via server)
```

**Nota:** Nunca expor `R2_SECRET_ACCESS_KEY` no cliente. Todas as operações de assinatura acontecem no servidor.

---

## 3. Instalação

```bash
npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

O R2 é compatível com a API S3 da AWS.

---

## 4. Cliente R2

```ts
// lib/storage/r2.ts
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const R2 = new S3Client({
  region: "auto",
  endpoint: process.env.R2_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});

const BUCKET = process.env.R2_BUCKET_NAME!;

// Gera URL assinada para upload (PUT)
export async function getUploadSignedUrl(
  key: string,
  contentType: string,
  expiresIn: number = 300 // 5 minutos
) {
  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: contentType,
  });

  return getSignedUrl(R2, command, { expiresIn });
}

// Gera URL assinada para download (GET)
export async function getDownloadSignedUrl(
  key: string,
  expiresIn: number = 3600 // 1 hora
) {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });

  return getSignedUrl(R2, command, { expiresIn });
}

// Elimina ficheiro
export async function deleteFile(key: string) {
  const command = new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });

  await R2.send(command);
}

// Gera chave única para o ficheiro
export function generateFileKey(
  organizacaoId: string,
  empresaId: string,
  documentoId: string,
  originalName: string
): string {
  const ext = originalName.split('.').pop();
  return `${organizacaoId}/${empresaId}/${documentoId}.${ext}`;
}
```

---

## 5. Fluxo de Upload Completo

### 5.1 Diagrama

```
     1. Pedir signed URL     
   Cliente    >  Server Action
  (Browser)                                  (Next.js)   
                              
                                                    
           2. Retorna signed URL + documentoId     
       <
                                                    
           3. Upload direto para R2 (PUT)          
       > 
                    (R2 Cloudflare)                 
                                                    
           4. Sucesso (HTTP 200)                   
       <
                                                    
           5. Confirmar upload + metadados         
       > 
                                                    
           6. Cria registo na BD (documentos)      
       <
```

### 5.2 Server Action — Gerar Signed URL

```ts
// app/actions/storage.ts
'use server';

import { createClient } from "@/lib/supabase/server";
import { getUploadSignedUrl, generateFileKey } from "@/lib/storage/r2";
import { z } from "zod";

const schema = z.object({
  empresaId: z.string().uuid(),
  tipoDocumento: z.string().min(1),
  ano: z.number().int().min(2000).max(2100),
  periodo: z.string().optional(),
  fileName: z.string().min(1),
  fileSize: z.number().max(50 * 1024 * 1024), // 50MB max
  contentType: z.enum(["application/pdf", "image/jpeg", "image/png"]),
});

export async function requestUploadUrl(input: z.infer<typeof schema>) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { success: false, error: "Não autenticado" };

  // Validar permissão (contabilista só pode upload para empresas atribuídas)
  const { data: atribuicao } = await supabase
    .from("contabilista_empresas")
    .select("*")
    .eq("contabilista_id", user.id)
    .eq("empresa_id", input.empresaId)
    .single();

  if (!atribuicao) return { success: false, error: "Sem permissão" };

  // Criar registo do documento na BD (estado = 'ativo' ou 'pendente')
  const { data: doc, error: docError } = await supabase
    .from("documentos")
    .insert({
      empresa_id: input.empresaId,
      organizacao_id: user.app_metadata.organizacao_id,
      tipo_documento: input.tipoDocumento,
      ano: input.ano,
      periodo: input.periodo,
      ficheiro_nome: input.fileName,
      ficheiro_tamanho: input.fileSize,
      estado: "ativo", // ou 'pendente' se for substituição
      criado_por: user.id,
    })
    .select()
    .single();

  if (docError || !doc) return { success: false, error: docError?.message };

  // Gerar chave e signed URL
  const key = generateFileKey(
    user.app_metadata.organizacao_id,
    input.empresaId,
    doc.id,
    input.fileName
  );

  const signedUrl = await getUploadSignedUrl(key, input.contentType);

  return {
    success: true,
    data: {
      signedUrl,
      documentoId: doc.id,
      fileKey: key,
    },
  };
}
```

### 5.3 Cliente — Upload para R2

```tsx
// components/forms/upload-documento.tsx
'use client';

import { requestUploadUrl } from "@/app/actions/storage";

export function UploadForm() {
  async function handleSubmit(formData: FormData) {
    const file = formData.get("file") as File;

    // 1. Pedir signed URL ao servidor
    const { success, data, error } = await requestUploadUrl({
      empresaId: "uuid-da-empresa",
      tipoDocumento: "Comparativo IVA",
      ano: 2023,
      fileName: file.name,
      fileSize: file.size,
      contentType: file.type as "application/pdf" | "image/jpeg" | "image/png",
    });

    if (!success) {
      alert(error);
      return;
    }

    // 2. Upload direto para R2
    const uploadRes = await fetch(data.signedUrl, {
      method: "PUT",
      body: file,
      headers: { "Content-Type": file.type },
    });

    if (!uploadRes.ok) {
      alert("Erro no upload para R2");
      return;
    }

    // 3. Confirmar (opcional — pode ser automático via webhook ou o registo já foi criado)
    alert("Upload completo!");
  }

  return (
    <form action={handleSubmit}>
      <input type="file" name="file" accept=".pdf,.jpg,.png" />
      <button type="submit">Carregar</button>
    </form>
  );
}
```

---

## 6. Fluxo de Download

### 6.1 Server Action — Gerar Signed URL de Download

```ts
// app/actions/storage.ts
export async function requestDownloadUrl(documentoId: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { success: false, error: "Não autenticado" };

  // Verificar permissão (RLS já filtra, mas validamos explicitamente)
  const { data: doc } = await supabase
    .from("documentos")
    .select("ficheiro_url, ficheiro_nome, estado")
    .eq("id", documentoId)
    .single();

  if (!doc || doc.estado !== "ativo") {
    return { success: false, error: "Documento não encontrado ou indisponível" };
  }

  // Extrair a chave do URL (ou guardar a chave R2 numa coluna separada)
  const key = doc.ficheiro_url.replace(process.env.R2_PUBLIC_URL + "/", "");

  const signedUrl = await getDownloadSignedUrl(key);

  // Log de acesso
  await supabase.from("log_acessos").insert({
    documento_id: documentoId,
    utilizador_id: user.id,
    acao: "transferiu",
  });

  return { success: true, data: { signedUrl, fileName: doc.ficheiro_nome } };
}
```

### 6.2 Cliente — Download

```tsx
async function downloadDocumento(documentoId: string) {
  const { success, data, error } = await requestDownloadUrl(documentoId);
  if (!success) { alert(error); return; }

  // Abre em nova aba ou faz download
  window.open(data.signedUrl, "_blank");
}
```

---

## 7. Eliminação de Ficheiros (Job de 90 Dias)

```ts
// supabase/functions/cleanup/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { S3Client, DeleteObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const R2 = new S3Client({
  region: "auto",
  endpoint: Deno.env.get("R2_ENDPOINT")!,
  credentials: {
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
  },
});

serve(async () => {
  // 1. Buscar documentos expirados
  const { data: docs } = await supabase
    .from("documentos")
    .select("id, ficheiro_url")
    .in("estado", ["rejeitado", "eliminado"])
    .lt("data_soft_delete", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString());

  if (!docs || docs.length === 0) {
    return new Response(JSON.stringify({ message: "Nada a eliminar" }), { status: 200 });
  }

  // 2. Eliminar ficheiros do R2 PRIMEIRO
  for (const doc of docs) {
    const key = doc.ficheiro_url.replace(Deno.env.get("R2_PUBLIC_URL") + "/", "");
    await R2.send(new DeleteObjectCommand({
      Bucket: Deno.env.get("R2_BUCKET_NAME")!,
      Key: key,
    }));
  }

  // 3. Eliminar registos da BD
  const ids = docs.map(d => d.id);
  await supabase.from("documentos").delete().in("id", ids);

  return new Response(JSON.stringify({ eliminados: ids.length }), { status: 200 });
});
```

**Regra de ouro:** Sempre eliminar o ficheiro do storage **antes** do registo da BD. Se falhar a meio, podes reprocessar. Se eliminares o registo primeiro, ficas com ficheiros órfãos.

---

## 8. Estrutura de Pastas no R2

```
bucket: documentos-consultoria
 organizacao-uuid-1/
    empresa-uuid-a/
       documento-uuid-1.pdf
       documento-uuid-2.jpg
    empresa-uuid-b/
        documento-uuid-3.pdf
 organizacao-uuid-2/
     ...
```

**Vantagem:** Fácil de navegar manualmente no R2 dashboard se necessário. Isolamento por organização.

---

## 9. Checklist de Segurança

- [ ] `R2_SECRET_ACCESS_KEY` nunca exposto no cliente
- [ ] Signed URLs com tempo de expiração curto (upload: 5min, download: 1h)
- [ ] Validação de tipo de ficheiro no servidor (magic bytes + content-type)
- [ ] Limite de tamanho no servidor (50MB)
- [ ] RLS na tabela `documentos` impede acesso a ficheiros de outras organizações
- [ ] Log de acesso registado em cada download
- [ ] Job de cleanup testado em staging antes de produção
