-- Migration: 003_empresas
-- Criação da tabela de empresas (clientes da contabilidade)
-- Tarefa: DB-003

-- ============================================
-- TABELA: empresas
-- ============================================

CREATE TABLE IF NOT EXISTS public.empresas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id UUID NOT NULL,
    nome TEXT NOT NULL,
    nif TEXT NOT NULL,
    contacto TEXT,
    ativa BOOLEAN NOT NULL DEFAULT true,
    criado_por UUID,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_empresas_organizacao
        FOREIGN KEY (organizacao_id)
        REFERENCES public.organizacoes(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_empresas_criado_por
        FOREIGN KEY (criado_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL,

    -- NIF único por organização (não global, para permitir mesma empresa em consultorias diferentes)
    CONSTRAINT uk_empresas_nif_organizacao
        UNIQUE (organizacao_id, nif)
);

-- Comentários
COMMENT ON TABLE public.empresas IS 'Empresas assistidas pela consultoria (clientes da contabilidade)';
COMMENT ON COLUMN public.empresas.nif IS 'NIF português da empresa (9 dígitos)';
COMMENT ON COLUMN public.empresas.contacto IS 'Email ou telefone de contacto da empresa';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_empresas_organizacao ON public.empresas(organizacao_id);
CREATE INDEX IF NOT EXISTS idx_empresas_nif ON public.empresas(nif);
CREATE INDEX IF NOT EXISTS idx_empresas_ativa ON public.empresas(ativa);
CREATE INDEX IF NOT EXISTS idx_empresas_nome ON public.empresas USING gin (nome gin_trgm_ops);

-- ============================================
-- TRIGGER: atualizar updated_at
-- ============================================

CREATE TRIGGER trg_empresas_updated_at
    BEFORE UPDATE ON public.empresas
    FOR EACH ROW
    EXECUTE FUNCTION public.atualizar_updated_at();

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Admin vê tudo da sua org
-- Contabilista vê apenas empresas atribuídas (via contabilista_empresas)
-- Cliente vê apenas empresas atribuídas (via cliente_empresas)
CREATE POLICY "empresas_select" ON public.empresas
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
    );

-- Nota: A filtragem por contabilista_empresas e cliente_empresas
-- será feita na aplicação ou via VIEW, pois RLS não permite
-- subqueries eficientes em policies de performance.
-- A policy acima garante isolamento por organização.
-- A filtragem adicional (atribuições) é feita nas queries da app.

-- Policy: INSERT
-- Super Admin ou Admin da mesma org
CREATE POLICY "empresas_insert" ON public.empresas
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
    );

-- Policy: UPDATE
-- Super Admin ou Admin da mesma org
CREATE POLICY "empresas_update" ON public.empresas
    FOR UPDATE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
    );

-- Policy: DELETE
-- Apenas Super Admin (soft delete via ativa = false preferido)
CREATE POLICY "empresas_delete" ON public.empresas
    FOR DELETE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );
