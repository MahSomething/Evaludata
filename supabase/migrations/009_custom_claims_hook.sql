-- Migration: 009_custom_claims_hook
-- Função PostgreSQL para injetar Custom Claims no JWT do Supabase Auth
-- Tarefa: DB-011

-- ============================================
-- FUNÇÃO: custom_access_token_hook
-- ============================================
-- Esta função é chamada pelo Supabase Auth sempre que um token JWT
-- é gerado (login, refresh, etc.). Ela adiciona claims customizadas
-- ao JWT com base nos dados do utilizador na tabela public.utilizadores.
--
-- NOTA: Esta função deve ser configurada no Supabase Dashboard:
-- Authentication → Hooks → "Custom Access Token Hook"
-- Selecionar: public.custom_access_token_hook

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_id UUID;
    user_record RECORD;
    claims jsonb;
BEGIN
    -- Extrair o user_id do evento
    user_id := (event ->> 'user_id')::UUID;

    -- Buscar dados do utilizador na nossa tabela
    SELECT 
        u.id,
        u.organizacao_id,
        u.papel::text,
        u.nome,
        u.ativo
    INTO user_record
    FROM public.utilizadores u
    WHERE u.id = user_id;

    -- Se não encontrar o utilizador, retornar o evento original
    -- (pode acontecer durante o registo inicial antes da criação na tabela public)
    IF user_record IS NULL THEN
        RETURN event;
    END IF;

    -- Se o utilizador estiver inativo, não adicionar claims
    -- (o login será rejeitado pela aplicação)
    IF NOT user_record.ativo THEN
        RETURN event;
    END IF;

    -- Construir as claims
    claims := jsonb_build_object(
        'organizacao_id', COALESCE(user_record.organizacao_id::text, ''),
        'papel', user_record.papel,
        'nome', user_record.nome
    );

    -- Adicionar as claims ao JWT (dentro de app_metadata ou custom claims)
    -- Usamos a chave 'app_metadata' que o Supabase já espera
    RETURN jsonb_set(
        event,
        '{claims,app_metadata}',
        COALESCE(event -> 'claims' -> 'app_metadata', '{}'::jsonb) || claims,
        true
    );
END;
$$;

-- Comentário
COMMENT ON FUNCTION public.custom_access_token_hook IS 
'Hook do Supabase Auth que injeta organizacao_id, papel e nome no JWT do utilizador. 
Configurar em: Dashboard → Authentication → Hooks → Custom Access Token Hook';

-- ============================================
-- PERMISSÕES
-- ============================================
-- A função precisa de ser executada pelo role 'supabase_auth_admin'
-- que é o role interno do Supabase Auth.

-- NOTA: O GRANT deve ser feito manualmente no Supabase SQL Editor
-- pois o role 'supabase_auth_admin' não existe em todos os ambientes.
-- 
-- Comando a executar no SQL Editor do Supabase Dashboard:
-- GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
--
-- OU, se usar o CLI:
-- supabase db push (após adicionar o GRANT a esta migration)

-- Tentativa de grant (pode falhar em ambientes locais sem o role)
DO $$
BEGIN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin';
EXCEPTION WHEN undefined_object THEN
    RAISE NOTICE 'Role supabase_auth_admin não encontrado — executar GRANT manualmente no Supabase Dashboard';
END $$;
