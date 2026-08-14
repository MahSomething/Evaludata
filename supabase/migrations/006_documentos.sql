-- Migration: 006_documentos
-- Criação da tabela de documentos com versionamento e aprovação
-- Tarefa: DB-005

-- ============================================
-- TIPO ENUM: estado_documento
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_documento_enum') THEN
        CREATE TYPE public.estado_documento_enum AS ENUM (
            'ativo',      -- Versão aprovada e atual
            'pendente',   -- Nova versão à espera de aprovação
            'rejeitado',  -- Versão rejeitada pelo admin
            'arquivado',  -- Versão anterior substituída
            'eliminado'   -- Soft delete (90 dias até remoção física)
        );
    END IF;
END $$;

-- ============================================
-- TABELA: documentos
-- ============================================

CREATE TABLE IF NOT EXISTS public.documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id UUID NOT NULL,
    organizacao_id UUID NOT NULL,
    tipo_documento TEXT NOT NULL,
    ano INTEGER NOT NULL CHECK (ano >= 2000 AND ano <= 2100),
    periodo TEXT,  -- ex: 'Q1', 'Janeiro', 'Dezembro', null
    ficheiro_url TEXT NOT NULL,
    ficheiro_nome TEXT NOT NULL,
    ficheiro_tamanho INTEGER NOT NULL CHECK (ficheiro_tamanho > 0),

    -- Versionamento / Aprovação
    versao INTEGER NOT NULL DEFAULT 1,
    documento_pai_id UUID,  -- Se for uma revisão de outro documento
    estado public.estado_documento_enum NOT NULL DEFAULT 'ativo',
    substitui_id UUID,  -- Qual documento esta versão substitui (se aplicável)

    -- Soft delete / retenção
    data_soft_delete TIMESTAMPTZ,

    -- Metadados flexíveis
    metadados JSONB DEFAULT '{}',
    notas TEXT,

    -- Auditoria
    criado_por UUID NOT NULL,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_por UUID,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Foreign Keys
    CONSTRAINT fk_documentos_empresa
        FOREIGN KEY (empresa_id)
        REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_documentos_organizacao
        FOREIGN KEY (organizacao_id)
        REFERENCES public.organizacoes(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_documentos_documento_pai
        FOREIGN KEY (documento_pai_id)
        REFERENCES public.documentos(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_documentos_substitui
        FOREIGN KEY (substitui_id)
        REFERENCES public.documentos(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_documentos_criado_por
        FOREIGN KEY (criado_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_documentos_atualizado_por
        FOREIGN KEY (atualizado_por)
        REFERENCES public.utilizadores(id)
        ON DELETE SET NULL
);

-- Comentários
COMMENT ON TABLE public.documentos IS 'Documentos fiscais e contabilísticos das empresas';
COMMENT ON COLUMN public.documentos.periodo IS 'Período do documento: mês, trimestre, ou outro identificador';
COMMENT ON COLUMN public.documentos.documento_pai_id IS 'Se este documento é uma revisão de outro, aponta para o original';
COMMENT ON COLUMN public.documentos.substitui_id IS 'Se este documento substitui outro, aponta para o documento substituído';
COMMENT ON COLUMN public.documentos.data_soft_delete IS 'Data em que o documento foi marcado como eliminado ou rejeitado (90 dias até remoção física)';
COMMENT ON COLUMN public.documentos.metadados IS 'Campos flexíveis em JSON para extensibilidade futura';

-- ============================================
-- ÍNDICES
-- ============================================

-- Índices principais para performance
CREATE INDEX IF NOT EXISTS idx_documentos_empresa ON public.documentos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_documentos_organizacao ON public.documentos(organizacao_id);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON public.documentos(estado);
CREATE INDEX IF NOT EXISTS idx_documentos_ano ON public.documentos(ano);
CREATE INDEX IF NOT EXISTS idx_documentos_tipo ON public.documentos(tipo_documento);

-- Índice composto para listagens comuns (empresa + estado + ano)
CREATE INDEX IF NOT EXISTS idx_documentos_empresa_estado_ano ON public.documentos(empresa_id, estado, ano DESC);

-- Índice para o job de cleanup (90 dias)
CREATE INDEX IF NOT EXISTS idx_documentos_soft_delete ON public.documentos(data_soft_delete) 
    WHERE data_soft_delete IS NOT NULL;

-- Índice para busca por nome/tipo/notas (full-text search)
CREATE INDEX IF NOT EXISTS idx_documentos_fts ON public.documentos 
    USING gin (to_tsvector('portuguese', 
        COALESCE(ficheiro_nome, '') || ' ' || 
        COALESCE(tipo_documento, '') || ' ' ||
        COALESCE(notas, '')
    ));

-- ============================================
-- TRIGGER: atualizar updated_at
-- ============================================

CREATE TRIGGER trg_documentos_updated_at
    BEFORE UPDATE ON public.documentos
    FOR EACH ROW
    EXECUTE FUNCTION public.atualizar_updated_at();

-- ============================================
-- RLS: Row Level Security
-- ============================================

ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT
-- Super Admin vê tudo
-- Admin vê tudo da sua org
-- Contabilista vê documentos das empresas atribuídas
-- Cliente vê apenas documentos 'ativo' das empresas atribuídas
CREATE POLICY "documentos_select" ON public.documentos
    FOR SELECT USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
        OR (
            (auth.jwt() ->> 'papel') = 'contabilista'
            AND empresa_id IN (
                SELECT empresa_id FROM public.contabilista_empresas
                WHERE contabilista_id = (auth.jwt() ->> 'sub')::UUID
            )
        )
        OR (
            estado = 'ativo'
            AND (auth.jwt() ->> 'papel') = 'cliente'
            AND empresa_id IN (
                SELECT empresa_id FROM public.cliente_empresas
                WHERE cliente_id = (auth.jwt() ->> 'sub')::UUID
            )
        )
    );

-- Policy: INSERT
-- Super Admin, Admin da org, ou Contabilista das empresas atribuídas
CREATE POLICY "documentos_insert" ON public.documentos
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
        OR (
            (auth.jwt() ->> 'papel') = 'contabilista'
            AND empresa_id IN (
                SELECT empresa_id FROM public.contabilista_empresas
                WHERE contabilista_id = (auth.jwt() ->> 'sub')::UUID
            )
        )
    );

-- Policy: UPDATE
-- Super Admin pode tudo
-- Admin pode atualizar tudo da sua org (aprovações, etc.)
-- Contabilista pode editar metadados dos seus próprios documentos
CREATE POLICY "documentos_update" ON public.documentos
    FOR UPDATE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
        OR (
            organizacao_id = (auth.jwt() ->> 'organizacao_id')::UUID
            AND (auth.jwt() ->> 'papel') = 'admin'
        )
        OR (
            criado_por = (auth.jwt() ->> 'sub')::UUID
            AND (auth.jwt() ->> 'papel') = 'contabilista'
            AND estado IN ('ativo', 'pendente', 'rejeitado', 'arquivado')
        )
    );

-- Policy: DELETE
-- Apenas Super Admin (soft delete via estado = 'eliminado' é o fluxo normal)
CREATE POLICY "documentos_delete" ON public.documentos
    FOR DELETE USING (
        (auth.jwt() ->> 'papel') = 'super_admin'
    );
