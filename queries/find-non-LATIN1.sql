-- file: find-non-UTF8.sql
-- descrition: Functions to find and replace NON LATIN1 chars in utf-8 database (REQUIRES review and testing)
-- version: >= 8.4
-- depends: NONE

CREATE OR REPLACE FUNCTION ajusta_nao_latin(cTabela TEXT, hColunasPK HSTORE, hColunas HSTORE)
RETURNS VOID as $$
DECLARE
    rChar       RECORD;
    rColunas    RECORD;
    cSET        TEXT[];
    cWHERE      TEXT[];
    cNovoValor  TEXT = '';
    cSQL        TEXT = '';
BEGIN

    FOR rColunas IN 
        SELECT
            key,
            value
        FROM each(hColunas)
        WHERE tem_nao_latin(value)
    LOOP
        cNovoValor = rColunas.value;
        -- RAISE NOTICE 'key: %, value: %', rColunas.key, rColunas.value;

        FOR rChar IN 
            SELECT 
                ascii(test_char) as ansi,
                test_char
            FROM (
                    SELECT UNNEST(REGEXP_SPLIT_TO_ARRAY(cNovoValor, '' )) as test_char
                ) as foo
            WHERE ascii(test_char) > 255
        LOOP
            cNovoValor = REPLACE(cNovoValor, rChar.test_char, ''::TEXT);
        END LOOP;

        cSET = array_append(cSET, rColunas.key || ' = ' || QUOTE_LITERAL(cNovoValor));

    END LOOP;


    FOR rColunas IN 
        SELECT
            key,
            value
        FROM each(hColunasPK)
    LOOP
        cWHERE = array_append(cWHERE, rColunas.key || ' = ' || QUOTE_LITERAL(rColunas.value));
    END LOOP;

    SELECT INTO cSQL
           'UPDATE ' 
        || cTabela 
        || ' SET '
        || ARRAY_TO_STRING(cSET, ', ')
        || ' WHERE '
        || ARRAY_TO_STRING(cWHERE, ' AND ')
        || ';';

    RAISE NOTICE 'ajusta_nao_latin|| QUERY: %', cSQL;
    PERFORM EXECUTE cSQL;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION tem_nao_latin(cValor TEXT)
RETURNS boolean as $$
DECLARE
    bRetorno    boolean = false;
    rChar       RECORD;
BEGIN

    FOR rChar IN 
        SELECT 
            ascii(test_char) as ansi,
            test_char
        FROM (
                SELECT UNNEST(REGEXP_SPLIT_TO_ARRAY(cValor, '' )) as test_char
            ) as foo
        WHERE ascii(test_char) > 255
    LOOP
        bRetorno = true;
        EXIT;
    END LOOP;

    RETURN bRetorno;

END;
$$ language 'plpgsql';




CREATE OR REPLACE FUNCTION busca_non_UTF8 (cTabela text) 
RETURNS VOID AS $$
DECLARE
    rColunas            RECORD;
    rColunasHSTORE      RECORD;
    rChar               RECORD;
    cColunasSelect      TEXT = '';
    cColunasHSTORE      TEXT = '';
    cColunasHStorePK    TEXT = '';
    cColunasWHERE       TEXT = '';
    cSQL                TEXT = '';
    rTabela             RECORD;
    cNomeColunaAtual    TEXT = '';
    cValorColunaAtual   TEXT = '';
    SEPARADOR_COLUNAS_ARRAY CONSTANT TEXT = '__X|X__';
BEGIN

    -- busca as colunas para montar o select
    SELECT INTO cColunasWHERE, cColunasHSTORE
        ARRAY_TO_STRING( 
            ARRAY_AGG(
                'tem_nao_latin(' 
                || pg_attribute.attname 
                || ')'
            ), 
        ' IS TRUE OR ') as regra_where,
        ARRAY_TO_STRING( 
            ARRAY_AGG(
                '(' 
                || QUOTE_LITERAL(pg_attribute.attname) 
                || ' => ' 
                || pg_attribute.attname 
                || ')::hstore'
            ), 
        ' || ') as reg

    FROM pg_attribute
    JOIN pg_class on pg_class.oid = pg_attribute.attrelid
    JOIN pg_type on pg_type.oid = pg_attribute.atttypid
    WHERE pg_class.relname = cTabela
      AND pg_type.typcategory = 'S';


    SELECT INTO cColunasHStorePK
        ARRAY_TO_STRING( 
            ARRAY_AGG(
                '(' 
                || QUOTE_LITERAL(pg_attribute.attname) 
                || ' => ' 
                || pg_attribute.attname 
                || ')::hstore'
            ), 
        ' || ') as reg

    FROM pg_attribute
    JOIN pg_class on pg_class.oid = pg_attribute.attrelid
    JOIN pg_index on pg_index.indrelid = pg_class.oid
    WHERE pg_class.relname = cTabela
      AND pg_attribute.attnum = any(pg_index.indkey)
      AND pg_index.indisprimary;

    IF cColunasHSTORE = '' THEN
        RAISE NOTICE 'Tabela \'%\' sem campos tipo string!', cTabela;
        RETURN ;
    END IF;

    cSQL = 'SELECT ' || cColunasHStorePK || ' AS pk, ' || cColunasHSTORE || ' as campos FROM ' || cTabela || ' WHERE ' || cColunasWHERE || ' LIMIT 100;';

    FOR rTabela IN EXECUTE cSQL
    LOOP
        PERFORM ajusta_nao_latin(cTabela, rTabela.pk, rTabela.campos);
    END LOOP;
    
    RETURN ;
END;
$$ LANGUAGE 'plpgsql'; 

set client_encoding = UTF8 ;

select busca_non_UTF8('cadastro');