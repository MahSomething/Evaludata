-- Migration: 008_otp_codes
-- Criação da tabela de códigos OTP para autenticação do cliente via WhatsApp
-- Tarefa: DB-007

-- ============================================
-- TABELA: otp_codes
-- ============================================

CREATE TABLE IF NOT EXISTS public.otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    utilizador_id UUID NOT NULL,
    telemovel TEXT NOT NULL,
    codigo TEXT NOT NULL,
    expira_em TIMESTAMPTZ NOT NULL,
    tentativas INTEGER NOT NULL DEFAULT 0,
    utilizado BOOLEAN NOT NULL DEFAULT false,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Key
    CONSTRAINT fk_otp_codes_utilizador
        FOREIGN KEY (utilizador_id)
        REFERENCES public.utilizadores(id)
        ON DELETE CASCADE
);

-- Comentários
COMMENT ON TABLE public.otp_codes IS 'Códigos OTP temporários para login do cliente via WhatsApp';
COMMENT ON COLUMN public.otp_codes.codigo IS 'Código de 6 dígitos enviado por WhatsApp';
COMMENT ON COLUMN public.otp_codes.expira_em IS 'Data/hora de expiração (padrão: 10 minutos após criação)';
COMMENT ON COLUMN public.otp_codes.tentativas IS 'Número de tentativas de validação (máx 3 antes de bloqueio)';
COMMENT ON COLUMN public.otp_codes.utilizado IS 'True se o código já foi usado com sucesso';

-- ============================================
-- ÍNDICES
-- ============================================

-- Índice principal para validação de OTP
CREATE INDEX IF NOT EXISTS idx_otp_codes_validacao 
    ON public.otp_codes(telemovel, codigo, expira_em) 
    WHERE utilizado = false;

-- Índice para cleanup de OTPs expirados
CREATE INDEX IF NOT EXISTS idx_otp_codes_expira ON public.otp_codes(expira_em);

-- Índice por utilizador
CREATE INDEX IF NOT EXISTS idx_otp_codes_utilizador ON public.otp_codes(utilizador_id);

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Apenas Super Admin ou o próprio utilizador (embora na prática
-- a validação seja feita via Server Action, não diretamente pelo cliente)
CREATE POLICY "otp_codes_select" ON public.otp_codes
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR utilizador_id = (auth.jwt() ->> 'sub')::UUID
    );

-- Policy: INSERT
-- Apenas via Server Action (qualquer utilizador autenticado pode pedir OTP,
-- mas na prática é o sistema que insere)
CREATE POLICY "otp_codes_insert" ON public.otp_codes
    FOR INSERT WITH CHECK (true);  -- Controlado pela aplicação

-- Policy: UPDATE
-- Apenas o próprio utilizador ou Super Admin
CREATE POLICY "otp_codes_update" ON public.otp_codes
    FOR UPDATE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR utilizador_id = (auth.jwt() ->> 'sub')::UUID
    );

-- Não há DELETE — OTPs expirados são limpos por job periódico
