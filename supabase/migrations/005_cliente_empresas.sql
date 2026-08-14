-- Migration: 005_cliente_empresas
-- Criação da tabela de ligação cliente → empresa
-- Tarefa: DB-004 (Parte 2/2)

-- ============================================
-- TABELA: cliente_empresas
-- ============================================

CREATE TABLE IF NOT EXISTS public.cliente_empresas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL,
    empresa_id UUID NOT NULL,
    atribuido_por UUID,
    atribuido_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_cliente_empresas_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES public.utilizadores(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cliente_empresas_empresa
        FOREIGN KEY (empresa_id)
        REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cliente_empresas_atribuido_por
        FOREIGN KEY (atribuido_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL,

    -- Um cliente só pode ser atribuído uma vez à mesma empresa
    CONSTRAINT uk_cliente_empresas
        UNIQUE (cliente_id, empresa_id)
);

-- Comentários
COMMENT ON TABLE public.cliente_empresas IS 'Matriz de acesso: quais empresas cada cliente pode visualizar no portal';

-- ============================================
-- ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_cliente_empresas_cliente ON public.cliente_empresas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_cliente_empresas_empresa ON public.cliente_empresas(empresa_id);

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.cliente_empresas ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Admin vê tudo da sua org (via empresa)
-- Cliente vê apenas as suas atribuições
CREATE POLICY "cliente_empresas_select" ON public.cliente_empresas
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR cliente_id = (auth.jwt() ->> 'sub')::UUID
        OR empresa_id IN (
            SELECT id FROM public.empresas
            WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
        )
    );

-- Policy: INSERT
-- Super Admin ou Admin (se a consultoria tem permissão pode_registar_clientes)
CREATE POLICY "cliente_empresas_insert" ON public.cliente_empresas
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            empresa_id IN (
                SELECT id FROM public.empresas
                WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            )
            AND (auth.jwt() ->> 'papel') = 'admin'
            AND EXISTS (
                SELECT 1 FROM public.organizacoes o
                WHERE o.id = (auth.jwt() ->> 'organizacao_id')::UUID
                AND o.pode_registar_clientes = true
            )
        )
    );

-- Policy: UPDATE/DELETE
-- Apenas Super Admin ou Admin da org da empresa
CREATE POLICY "cliente_empresas_write" ON public.cliente_empresas
    FOR ALL USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR empresa_id IN (
            SELECT id FROM public.empresas
            WHERE organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
    );
