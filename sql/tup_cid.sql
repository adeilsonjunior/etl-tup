-- tup_cid.sql
-- Tabelas de CID do TUP (Oracle RJPO1DR, schema TUP) no PostgreSQL, e a view tup.vw_cid
-- no mesmo formato de sigtap.tb_cid (co_cid, no_cid, tp_sexo, tp_agravo), para o app
-- deixar de depender do schema sigtap, que está sem carga.
--
-- Colunas iguais às do Oracle (o job copia com SELECT *, casando as colunas pelo nome).
-- Rodar UMA vez, ANTES da primeira execução do job com as tabelas de CID. Pode ser repetido sem erro.
--
--   docker exec -i postgres psql -U postgres -d dbcontroleavaliacao < sql/tup_cid.sql

BEGIN;

CREATE TABLE IF NOT EXISTS tup.tb_cid_capitulo (
    co_cid_capitulo      varchar(2)   NOT NULL,
    no_cid_capitulo      varchar(250) NOT NULL,
    no_cid_capitulo_100  varchar(100) NOT NULL,
    no_cid_capitulo_50   varchar(50)  NOT NULL,
    no_cid_capitulo_cns  varchar(105),
    dt_inclusao          timestamp    NOT NULL,
    no_usuario_inclusao  varchar(20)  NOT NULL,
    dt_exclusao          timestamp,
    no_usuario_exclusao  varchar(20)
);

CREATE TABLE IF NOT EXISTS tup.tb_cid_grupo (
    co_cid_categoria_inicial varchar(3)   NOT NULL,
    co_cid_categoria_final   varchar(3)   NOT NULL,
    no_cid_grupo             varchar(250) NOT NULL,
    no_cid_grupo_100         varchar(100) NOT NULL,
    no_cid_grupo_50          varchar(50)  NOT NULL,
    no_cid_grupo_cns         varchar(50),
    dt_inclusao              timestamp    NOT NULL,
    no_usuario_inclusao      varchar(20)  NOT NULL,
    dt_exclusao              timestamp,
    no_usuario_exclusao      varchar(20)
);

CREATE TABLE IF NOT EXISTS tup.tb_cid_categoria (
    co_cid_categoria      varchar(3)   NOT NULL,
    no_cid_categoria      varchar(250) NOT NULL,
    no_cid_categoria_100  varchar(100) NOT NULL,
    no_cid_categoria_50   varchar(50)  NOT NULL,
    no_cid_categoria_cns  varchar(50),
    dt_inclusao           timestamp    NOT NULL,
    no_usuario_inclusao   varchar(20)  NOT NULL,
    dt_exclusao           timestamp,
    no_usuario_exclusao   varchar(20),
    co_cid_capitulo       varchar(2)   NOT NULL
);

CREATE TABLE IF NOT EXISTS tup.tb_cid_subcategoria (
    co_cid_subcategoria      varchar(4)   NOT NULL,
    no_cid_subcategoria      varchar(300) NOT NULL,
    no_cid_subcategoria_100  varchar(100) NOT NULL,
    no_cid_subcategoria_50   varchar(50)  NOT NULL,
    no_cid_subcategoria_cns  varchar(50),
    tp_sexo                  char(1)      NOT NULL,
    tp_agravo                char(1)      NOT NULL,
    tp_opcao                 char(1),
    dt_inclusao              timestamp    NOT NULL,
    no_usuario_inclusao      varchar(20)  NOT NULL,
    dt_exclusao              timestamp,
    no_usuario_exclusao      varchar(20),
    co_cid_categoria         varchar(3)   NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tb_cid_categoria_co    ON tup.tb_cid_categoria (co_cid_categoria);
CREATE INDEX IF NOT EXISTS idx_tb_cid_subcategoria_co ON tup.tb_cid_subcategoria (co_cid_subcategoria);

-- Formato de sigtap.tb_cid: um registro por código, de 3 caracteres (ex.: A33) ou 4 (ex.: A330).
-- O TUP já traz os códigos de 3 caracteres também em tb_cid_subcategoria (com sexo e agravo):
-- vale a subcategoria; a categoria só entra quando o código não existe como subcategoria.
-- Inclui os códigos excluídos (fl_excluido = true), para ocorrências antigas não perderem a descrição.
CREATE OR REPLACE VIEW tup.vw_cid AS
SELECT s.co_cid_subcategoria        AS co_cid,
       s.no_cid_subcategoria        AS no_cid,
       s.tp_sexo,
       s.tp_agravo,
       (s.dt_exclusao IS NOT NULL)  AS fl_excluido
  FROM tup.tb_cid_subcategoria s
UNION ALL
SELECT c.co_cid_categoria,
       c.no_cid_categoria,
       NULL::char(1),
       NULL::char(1),
       (c.dt_exclusao IS NOT NULL)
  FROM tup.tb_cid_categoria c
 WHERE NOT EXISTS (SELECT 1 FROM tup.tb_cid_subcategoria s WHERE s.co_cid_subcategoria = c.co_cid_categoria);

COMMENT ON VIEW tup.vw_cid IS
    'CIDs do TUP no formato de sigtap.tb_cid: categorias (3 caracteres) e subcategorias (4). Carga diária pelo job tup (etl-tup).';

COMMIT;

-- Conferência (depois da carga):
--   SELECT length(co_cid), count(*), count(*) FILTER (WHERE fl_excluido) FROM tup.vw_cid GROUP BY 1;
--   -- Código repetido (deve vir 0):
--   SELECT count(*) FROM (SELECT co_cid FROM tup.vw_cid GROUP BY 1 HAVING count(*) > 1) x;
--   -- CIDs do sigtap que não estão no TUP (deve vir vazio ou quase):
--   SELECT s.co_cid FROM sigtap.tb_cid s LEFT JOIN tup.vw_cid t ON t.co_cid = s.co_cid WHERE t.co_cid IS NULL LIMIT 20;
