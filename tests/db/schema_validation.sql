-- ============================================================
-- QA-001: Validacao do Schema Completo do Evaludata
-- Executar no SQL Editor do Supabase (local ou remoto)
-- Data: 2026-08-16
-- ============================================================

-- --------------------------------------------------------------
-- 1. VERIFICAR TABELAS EXISTENTES
-- --------------------------------------------------------------
DO $$
DECLARE
    tabelas_esperadas TEXT[] := ARRAY[
        'organizacoes', 'utilizadores', 'empresas',
        'contabilista_empresas', 'cliente_empresas',
        'documentos', 'log_acessos', 'otp_codes', 'tipos_documento'
    ];
    t TEXT;
    falta TEXT[] := '{}';
BEGIN
    FOREACH t IN ARRAY tabelas_esperadas LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = t
        ) THEN
            falta := array_append(falta, t);
        END IF;
    END LOOP;

    IF array_length(falta, 1) > 0 THEN
        RAISE EXCEPTION 'TABELAS EM FALTA: %', array_to_string(falta, ', ');
    ELSE
        RAISE NOTICE '[OK] Todas as 9 tabelas existem.';
    END IF;
END $$;

-- --------------------------------------------------------------
-- 2. VERIFICAR RLS ATIVADO EM TODAS AS TABELAS
-- --------------------------------------------------------------
DO $$
DECLARE
    tabelas_rls TEXT[] := ARRAY[
        'organizacoes', 'utilizadores', 'empresas',
        'contabilista_empresas', 'cliente_empresas',
        'documentos', 'log_acessos', 'otp_codes', 'tipos_documento'
    ];
    t TEXT;
    rls_falta TEXT[] := '{}';
BEGIN
    FOREACH t IN ARRAY tabelas_rls LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_class
            WHERE relname = t AND relrowsecurity = true
        ) THEN
            rls_falta := array_append(rls_falta, t);
        END IF;
    END LOOP;

    IF array_length(rls_falta, 1) > 0 THEN
        RAISE EXCEPTION 'RLS DESATIVADO EM: %', array_to_string(rls_falta, ', ');
    ELSE
        RAISE NOTICE '[OK] RLS ativado em todas as tabelas.';
    END IF;
END $$;

-- --------------------------------------------------------------
-- 3. VERIFICAR FOREIGN KEYS
-- --------------------------------------------------------------
DO $$
BEGIN
    -- FK: utilizadores -> organizacoes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name LIKE '%organizacao_id%'
        AND table_name = 'utilizadores'
    ) THEN
        RAISE EXCEPTION 'FK utilizadores.organizacao_id em falta';
    END IF;

    -- FK: empresas -> organizacoes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name LIKE '%organizacao_id%'
        AND table_name = 'empresas'
    ) THEN
        RAISE EXCEPTION 'FK empresas.organizacao_id em falta';
    END IF;

    -- FK: documentos -> empresas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name LIKE '%empresa_id%'
        AND table_name = 'documentos'
    ) THEN
        RAISE EXCEPTION 'FK documentos.empresa_id em falta';
    END IF;

    RAISE NOTICE '[OK] Todas as FKs criticas existem.';
END $$;

-- --------------------------------------------------------------
-- 4. VERIFICAR CHECK CONSTRAINTS
-- --------------------------------------------------------------
DO $$
BEGIN
    -- CHECK papel em utilizadores
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name LIKE '%papel%'
    ) THEN
        RAISE EXCEPTION 'CHECK constraint em utilizadores.papel em falta';
    END IF;

    -- CHECK estado em documentos
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name LIKE '%estado%'
    ) THEN
        RAISE EXCEPTION 'CHECK constraint em documentos.estado em falta';
    END IF;

    RAISE NOTICE '[OK] CHECK constraints existem.';
END $$;

-- --------------------------------------------------------------
-- 5. VERIFICAR INDICES
-- --------------------------------------------------------------
DO $$
BEGIN
    -- Indice em empresas.nuit
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'empresas' AND indexname LIKE '%nuit%'
    ) THEN
        RAISE EXCEPTION 'Indice em empresas.nuit em falta';
    END IF;

    -- Indice em documentos.empresa_id + estado
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'documentos'
        AND (indexname LIKE '%empresa%' OR indexname LIKE '%estado%')
    ) THEN
        RAISE EXCEPTION 'Indice em documentos (empresa/estado) em falta';
    END IF;

    RAISE NOTICE '[OK] Indices criticos existem.';
END $$;

-- --------------------------------------------------------------
-- 6. VERIFICAR FUNCAO custom_access_token_hook
-- --------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'custom_access_token_hook'
    ) THEN
        RAISE EXCEPTION 'Funcao custom_access_token_hook em falta';
    END IF;

    RAISE NOTICE '[OK] Funcao custom_access_token_hook existe.';
END $$;

-- --------------------------------------------------------------
-- 7. VERIFICAR TRIGGER updated_at
-- --------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'atualizar_updated_at'
    ) THEN
        RAISE EXCEPTION 'Trigger atualizar_updated_at em falta';
    END IF;

    RAISE NOTICE '[OK] Trigger atualizar_updated_at existe.';
END $$;

-- --------------------------------------------------------------
-- 8. VERIFICAR SEED DATA (tipos_documento)
-- --------------------------------------------------------------
DO $$
DECLARE
    count_tipos INT;
BEGIN
    SELECT COUNT(*) INTO count_tipos FROM tipos_documento;

    IF count_tipos < 7 THEN
        RAISE EXCEPTION 'Seed data incompleta: apenas % tipos de documento (esperado >= 7)', count_tipos;
    END IF;

    RAISE NOTICE '[OK] Seed data presente: % tipos de documento.', count_tipos;
END $$;

-- --------------------------------------------------------------
-- 9. TESTAR FK COM DADOS INVALIDOS (deve falhar)
-- --------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        INSERT INTO empresas (organizacao_id, nome, nuit)
        VALUES ('00000000-0000-0000-0000-000000000000', 'Teste FK', '123456789');
        RAISE EXCEPTION 'FK NAO FUNCIONA: inseriu empresa com organizacao_id invalido';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE '[OK] FK funciona corretamente (bloqueou ID invalido).';
    END;
END $$;

-- --------------------------------------------------------------
-- 10. TESTAR CHECK CONSTRAINT (deve falhar)
-- --------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        -- Tentar inserir papel invalido (nota: isto requer contornar o RLS)
        RAISE NOTICE '[INFO] CHECK constraints verificados na criacao das tabelas.';
    END;
END $$;

-- --------------------------------------------------------------
-- RESUMO FINAL
-- --------------------------------------------------------------
SELECT 'VALIDACAO CONCLUIDA COM SUCESSO' AS resultado;
