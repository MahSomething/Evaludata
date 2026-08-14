-- Migration: 007_log_acessos
-- Criação da tabela de auditoria de acessos
-- Tarefa: DB-006

-- ============================================
-- TIPO ENUM: tipo_acao
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_acao_enum') THEN
        CREATE TYPE public.tipo_acao_enum AS ENUM (
            'visualizou',
            'transferiu',
            'aprovou',
            'rejeitou'
        );
    END IF;
END $$;

-- ============================================
-- TABELA: log_acessos
-- ============================================

CREATE TABLE IF NOT EXISTS public.log_acessos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    documento_id UUID NOT NULL,
    utilizador_id UUID NOT NULL,
    acao public.tipo_acao_enum NOT NULL,
    ip TEXT,
    user_agent TEXT,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_log_acessos_documento
        FOREIGN KEY (documento_id)
        REFERENCES public.documentos(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_log_acessos_utilizador
        FOREIGN KEY (utilizador_id)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL
);

-- Comentários
COMMENT ON TABLE public.log_acessos IS 'Auditoria: quem viu, transferiu, aprovou ou rejeitou cada documento';
COMMENT ON COLUMN public.log_acessos.ip IS 'Endereço IP do utilizador no momento da ação';
COMMENT ON COLUMN public.log_acessos.user_agent IS 'User-Agent do browser/dispositivo';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_log_acessos_documento ON public.log_acessos(documento_id);
CREATE INDEX IF NOT EXISTS idx_log_acessos_utilizador ON public.log_acessos(utilizador_id);
CREATE INDEX IF NOT EXISTS idx_log_acessos_criado_em ON public.log_acessos(criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_log_acessos_documento_criado ON public.log_acessos(documento_id, criado_em DESC);

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.log_acessos ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Admin vê logs da sua org (via documento)
-- Contabilista/Cliente vêem apenas os seus próprios logs
CREATE POLICY "log_acessos_select" ON public.log_acessos
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR documento_id IN (
            SELECT id FROM public.documentos
            WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
        )
        OR utilizador_id = (auth.jwt() ->> 'sub')::UUID
    );

-- Policy: INSERT
-- Apenas via service role ou trigger (nunca diretamente pelo utilizador)
-- A aplicação usa uma função segura ou server action com service role
CREATE POLICY "log_acessos_insert" ON public.log_acessos
    FOR INSERT WITH CHECK (false);

-- Não há UPDATE nem DELETE — tabela imutável
