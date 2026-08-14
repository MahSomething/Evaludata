-- Migration: 004_contabilista_empresas
-- Criação da tabela de ligação contabilista → empresa
-- Tarefa: DB-004 (Parte 1/2)

-- ============================================
-- TABELA: contabilista_empresas
-- ============================================

CREATE TABLE IF NOT EXISTS public.contabilista_empresas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contabilista_id UUID NOT NULL,
    empresa_id UUID NOT NULL,
    atribuido_por UUID,
    atribuido_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_contabilista_empresas_contabilista
        FOREIGN KEY (contabilista_id)
        REFERENCES public.utilizadores(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_contabilista_empresas_empresa
        FOREIGN KEY (empresa_id)
        REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_contabilista_empresas_atribuido_por
        FOREIGN KEY (atribuido_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL,

    -- Um contabilista só pode ser atribuído uma vez à mesma empresa
    CONSTRAINT uk_contabilista_empresas
        UNIQUE (contabilista_id, empresa_id)
);

-- Comentários
COMMENT ON TABLE public.contabilista_empresas IS 'Matriz de acesso: quais empresas cada contabilista pode ver/gerir';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_contabilista_empresas_contabilista ON public.contabilista_empresas(contabilista_id);
CREATE INDEX IF NOT EXISTS idx_contabilista_empresas_empresa ON public.contabilista_empresas(empresa_id);

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.contabilista_empresas ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Admin vê tudo da sua org (via empresa)
-- Contabilista vê apenas as suas atribuições
CREATE POLICY "contabilista_empresas_select" ON public.contabilista_empresas
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR contabilista_id = (auth.jwt() ->> 'sub')::UUID
        OR empresa_id IN (
            SELECT id FROM public.empresas
            WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
        )
    );

-- Policy: INSERT/UPDATE/DELETE
-- Apenas Super Admin ou Admin da org da empresa
CREATE POLICY "contabilista_empresas_write" ON public.contabilista_empresas
    FOR ALL USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR empresa_id IN (
            SELECT id FROM public.empresas
            WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
    );
