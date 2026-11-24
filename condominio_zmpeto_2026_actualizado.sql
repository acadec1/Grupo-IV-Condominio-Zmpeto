-- =====================================================================
-- PROJECTO: Sistema de Gestao do Condominio Zmpeto
-- BASE/SCHEMA: CONDOMINIO_DB
-- SGBD: Oracle Database
-- ENTREGA II - Implementacao da base de dados
-- =====================================================================
-- VERSAO REVISTA: dados de demonstracao de Janeiro a Novembro de 2026.
-- EXECUTAR APENAS NUM SCHEMA CONDOMINIO_DB VAZIO, usando F5.
-- Se ja houver tabelas, NAO executar novamente: ORA-00955.
-- INSTRUCAO:
-- Execute este script no Oracle SQL Developer ligado ao schema
-- CONDOMINIO_DB. A seccao 0 (criacao do utilizador/schema) deve ser
-- executada apenas por um utilizador com privilegios administrativos.
-- =====================================================================

-- =====================================================================
-- 0. CRIACAO OPCIONAL DO SCHEMA CONDOMINIO_DB (EXECUTAR COMO ADMIN)
-- =====================================================================
-- CREATE USER CONDOMINIO_DB IDENTIFIED BY Condominio2026;
-- GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE,
--       CREATE TRIGGER, CREATE PROCEDURE, CREATE VIEW TO CONDOMINIO_DB;
-- ALTER USER CONDOMINIO_DB QUOTA UNLIMITED ON USERS;
-- Depois, ligar no SQL Developer como CONDOMINIO_DB e executar o restante.

-- Verificacao de seguranca: nao executar em schema errado ou com tabelas existentes.
WHENEVER SQLERROR EXIT SQL.SQLCODE
DECLARE
    v_total NUMBER;
BEGIN
    IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA') <> 'CONDOMINIO_DB' OR USER <> 'CONDOMINIO_DB' THEN
        RAISE_APPLICATION_ERROR(-20990, 'Ligar como CONDOMINIO_DB antes de executar.');
    END IF;
    SELECT COUNT(*) INTO v_total FROM USER_TABLES
     WHERE TABLE_NAME IN ('CONDOMINIO','APARTAMENTO','CONDOMINO','OCUPACAO',
       'QUOTA','PAGAMENTO','DESPESA','OCORRENCIA_MANUTENCAO','AVISO','AVISO_DESTINATARIO');
    IF v_total > 0 THEN
        RAISE_APPLICATION_ERROR(-20991, 'Ja existem tabelas do projecto. Nao repetir o script.');
    END IF;
END;
/
WHENEVER SQLERROR CONTINUE

-- =====================================================================
-- 1. TABELAS, CHAVES E RESTRICOES
-- =====================================================================

CREATE TABLE CONDOMINIO (
    id_condominio NUMBER(10)      CONSTRAINT pk_condominio PRIMARY KEY,
    nome          VARCHAR2(100)   CONSTRAINT nn_condominio_nome NOT NULL,
    endereco      VARCHAR2(200)   CONSTRAINT nn_condominio_endereco NOT NULL,
    contacto      VARCHAR2(30)
);

CREATE TABLE APARTAMENTO (
    id_apartamento NUMBER(10)     CONSTRAINT pk_apartamento PRIMARY KEY,
    id_condominio  NUMBER(10)     CONSTRAINT nn_apart_condominio NOT NULL,
    bloco          VARCHAR2(20)   CONSTRAINT nn_apart_bloco NOT NULL,
    numero         VARCHAR2(20)   CONSTRAINT nn_apart_numero NOT NULL,
    tipologia      VARCHAR2(10)   CONSTRAINT nn_apart_tipologia NOT NULL,
    estado         VARCHAR2(20) DEFAULT 'DISPONIVEL'
                                  CONSTRAINT nn_apart_estado NOT NULL,
    CONSTRAINT fk_apart_condominio FOREIGN KEY (id_condominio)
        REFERENCES CONDOMINIO(id_condominio),
    CONSTRAINT uq_apart_unidade UNIQUE (id_condominio, bloco, numero),
    CONSTRAINT ck_apart_tipologia CHECK (tipologia IN ('T1','T2','T3','T4')),
    CONSTRAINT ck_apart_estado CHECK (estado IN ('DISPONIVEL','OCUPADO','MANUTENCAO'))
);

CREATE TABLE CONDOMINO (
    id_condomino NUMBER(10)       CONSTRAINT pk_condomino PRIMARY KEY,
    nome         VARCHAR2(120)    CONSTRAINT nn_condomino_nome NOT NULL,
    bi_nuit      VARCHAR2(30)     CONSTRAINT nn_condomino_bi_nuit NOT NULL,
    telefone     VARCHAR2(30)     CONSTRAINT nn_condomino_telefone NOT NULL,
    email        VARCHAR2(120),
    CONSTRAINT uq_condomino_bi_nuit UNIQUE (bi_nuit),
    CONSTRAINT uq_condomino_email UNIQUE (email)
);

CREATE TABLE OCUPACAO (
    id_ocupacao    NUMBER(10)     CONSTRAINT pk_ocupacao PRIMARY KEY,
    id_condomino   NUMBER(10)     CONSTRAINT nn_ocup_condomino NOT NULL,
    id_apartamento NUMBER(10)     CONSTRAINT nn_ocup_apart NOT NULL,
    tipo_relacao   VARCHAR2(20)   CONSTRAINT nn_ocup_tipo NOT NULL,
    data_inicio    DATE           CONSTRAINT nn_ocup_inicio NOT NULL,
    data_fim       DATE,
    CONSTRAINT fk_ocup_condomino FOREIGN KEY (id_condomino)
        REFERENCES CONDOMINO(id_condomino),
    CONSTRAINT fk_ocup_apartamento FOREIGN KEY (id_apartamento)
        REFERENCES APARTAMENTO(id_apartamento),
    CONSTRAINT ck_ocup_tipo CHECK (tipo_relacao IN ('PROPRIETARIO','MORADOR')),
    CONSTRAINT ck_ocup_datas CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

CREATE TABLE QUOTA (
    id_quota        NUMBER(10)    CONSTRAINT pk_quota PRIMARY KEY,
    id_apartamento  NUMBER(10)    CONSTRAINT nn_quota_apart NOT NULL,
    mes_referencia  DATE          CONSTRAINT nn_quota_mes NOT NULL,
    valor            NUMBER(12,2) CONSTRAINT nn_quota_valor NOT NULL,
    data_vencimento DATE          CONSTRAINT nn_quota_venc NOT NULL,
    estado           VARCHAR2(20) DEFAULT 'PENDENTE'
                                  CONSTRAINT nn_quota_estado NOT NULL,
    CONSTRAINT fk_quota_apartamento FOREIGN KEY (id_apartamento)
        REFERENCES APARTAMENTO(id_apartamento),
    CONSTRAINT uq_quota_apart_mes UNIQUE (id_apartamento, mes_referencia),
    CONSTRAINT ck_quota_valor CHECK (valor > 0),
    CONSTRAINT ck_quota_estado CHECK (estado IN ('PENDENTE','PARCIAL','PAGA','ATRASADA')),
    CONSTRAINT ck_quota_mes CHECK (mes_referencia = TRUNC(mes_referencia, 'MM'))
);

CREATE TABLE PAGAMENTO (
    id_pagamento   NUMBER(10)     CONSTRAINT pk_pagamento PRIMARY KEY,
    id_quota       NUMBER(10)     CONSTRAINT nn_pag_quota NOT NULL,
    data_pagamento DATE DEFAULT SYSDATE
                                  CONSTRAINT nn_pag_data NOT NULL,
    valor_pago     NUMBER(12,2)   CONSTRAINT nn_pag_valor NOT NULL,
    metodo         VARCHAR2(30)   CONSTRAINT nn_pag_metodo NOT NULL,
    referencia     VARCHAR2(60),
    CONSTRAINT fk_pag_quota FOREIGN KEY (id_quota)
        REFERENCES QUOTA(id_quota),
    CONSTRAINT ck_pag_valor CHECK (valor_pago > 0),
    CONSTRAINT ck_pag_metodo CHECK (metodo IN ('TRANSFERENCIA','DEPOSITO','NUMERARIO','MPESA','EMOLA')),
    CONSTRAINT uq_pag_referencia UNIQUE (referencia)
);

CREATE TABLE DESPESA (
    id_despesa    NUMBER(10)      CONSTRAINT pk_despesa PRIMARY KEY,
    id_condominio NUMBER(10)      CONSTRAINT nn_desp_condominio NOT NULL,
    categoria     VARCHAR2(50)    CONSTRAINT nn_desp_categoria NOT NULL,
    descricao     VARCHAR2(250)   CONSTRAINT nn_desp_descricao NOT NULL,
    valor         NUMBER(12,2)    CONSTRAINT nn_desp_valor NOT NULL,
    data_despesa  DATE DEFAULT SYSDATE
                                  CONSTRAINT nn_desp_data NOT NULL,
    CONSTRAINT fk_desp_condominio FOREIGN KEY (id_condominio)
        REFERENCES CONDOMINIO(id_condominio),
    CONSTRAINT ck_desp_valor CHECK (valor > 0),
    CONSTRAINT ck_desp_categoria CHECK (categoria IN
        ('AGUA','ENERGIA','LIMPEZA','SEGURANCA','MANUTENCAO','ADMINISTRACAO','OUTROS'))
);

CREATE TABLE OCORRENCIA_MANUTENCAO (
    id_ocorrencia  NUMBER(10)     CONSTRAINT pk_ocorrencia PRIMARY KEY,
    id_condominio  NUMBER(10)     CONSTRAINT nn_ocorr_condominio NOT NULL,
    id_apartamento NUMBER(10),
    titulo         VARCHAR2(120)  CONSTRAINT nn_ocorr_titulo NOT NULL,
    descricao      VARCHAR2(500)  CONSTRAINT nn_ocorr_descricao NOT NULL,
    prioridade     VARCHAR2(15)   CONSTRAINT nn_ocorr_prioridade NOT NULL,
    estado         VARCHAR2(20) DEFAULT 'ABERTA'
                                  CONSTRAINT nn_ocorr_estado NOT NULL,
    data_abertura  DATE DEFAULT SYSDATE
                                  CONSTRAINT nn_ocorr_abertura NOT NULL,
    data_fecho     DATE,
    CONSTRAINT fk_ocorr_condominio FOREIGN KEY (id_condominio)
        REFERENCES CONDOMINIO(id_condominio),
    CONSTRAINT fk_ocorr_apartamento FOREIGN KEY (id_apartamento)
        REFERENCES APARTAMENTO(id_apartamento),
    CONSTRAINT ck_ocorr_prioridade CHECK (prioridade IN ('BAIXA','MEDIA','ALTA','URGENTE')),
    CONSTRAINT ck_ocorr_estado CHECK (estado IN ('ABERTA','EM_CURSO','FECHADA')),
    CONSTRAINT ck_ocorr_datas CHECK (data_fecho IS NULL OR data_fecho >= data_abertura)
);

CREATE TABLE AVISO (
    id_aviso        NUMBER(10)    CONSTRAINT pk_aviso PRIMARY KEY,
    id_condominio   NUMBER(10)    CONSTRAINT nn_aviso_condominio NOT NULL,
    titulo          VARCHAR2(120) CONSTRAINT nn_aviso_titulo NOT NULL,
    mensagem        VARCHAR2(1000) CONSTRAINT nn_aviso_mensagem NOT NULL,
    data_publicacao DATE DEFAULT SYSDATE
                                  CONSTRAINT nn_aviso_data NOT NULL,
    validade        DATE,
    CONSTRAINT fk_aviso_condominio FOREIGN KEY (id_condominio)
        REFERENCES CONDOMINIO(id_condominio),
    CONSTRAINT ck_aviso_validade CHECK (validade IS NULL OR validade >= data_publicacao)
);

CREATE TABLE AVISO_DESTINATARIO (
    id_aviso       NUMBER(10) CONSTRAINT nn_avdest_aviso NOT NULL,
    id_apartamento NUMBER(10) CONSTRAINT nn_avdest_apart NOT NULL,
    CONSTRAINT pk_aviso_destinatario PRIMARY KEY (id_aviso, id_apartamento),
    CONSTRAINT fk_avdest_aviso FOREIGN KEY (id_aviso)
        REFERENCES AVISO(id_aviso) ON DELETE CASCADE,
    CONSTRAINT fk_avdest_apart FOREIGN KEY (id_apartamento)
        REFERENCES APARTAMENTO(id_apartamento)
);

-- =====================================================================
-- 2. SEQUENCIAS
-- =====================================================================
CREATE SEQUENCE seq_condominio START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_apartamento START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_condomino START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_ocupacao START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_quota START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_pagamento START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_despesa START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_ocorrencia START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_aviso START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================

-- 3.1 Atribuicao automatica de IDs pelas sequencias.
CREATE OR REPLACE TRIGGER trg_bi_condominio
BEFORE INSERT ON CONDOMINIO FOR EACH ROW
WHEN (NEW.id_condominio IS NULL)
BEGIN
    :NEW.id_condominio := seq_condominio.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_apartamento
BEFORE INSERT ON APARTAMENTO FOR EACH ROW
WHEN (NEW.id_apartamento IS NULL)
BEGIN
    :NEW.id_apartamento := seq_apartamento.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_condomino
BEFORE INSERT ON CONDOMINO FOR EACH ROW
WHEN (NEW.id_condomino IS NULL)
BEGIN
    :NEW.id_condomino := seq_condomino.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_ocupacao
BEFORE INSERT ON OCUPACAO FOR EACH ROW
WHEN (NEW.id_ocupacao IS NULL)
BEGIN
    :NEW.id_ocupacao := seq_ocupacao.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_quota
BEFORE INSERT ON QUOTA FOR EACH ROW
WHEN (NEW.id_quota IS NULL)
BEGIN
    :NEW.id_quota := seq_quota.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_pagamento
BEFORE INSERT ON PAGAMENTO FOR EACH ROW
WHEN (NEW.id_pagamento IS NULL)
BEGIN
    :NEW.id_pagamento := seq_pagamento.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_despesa
BEFORE INSERT ON DESPESA FOR EACH ROW
WHEN (NEW.id_despesa IS NULL)
BEGIN
    :NEW.id_despesa := seq_despesa.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_ocorrencia
BEFORE INSERT ON OCORRENCIA_MANUTENCAO FOR EACH ROW
WHEN (NEW.id_ocorrencia IS NULL)
BEGIN
    :NEW.id_ocorrencia := seq_ocorrencia.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_aviso
BEFORE INSERT ON AVISO FOR EACH ROW
WHEN (NEW.id_aviso IS NULL)
BEGIN
    :NEW.id_aviso := seq_aviso.NEXTVAL;
END;
/

-- 3.2 Mantem o estado da quota apos INSERT/UPDATE/DELETE em PAGAMENTO.
CREATE OR REPLACE TRIGGER trg_pagamento_actualiza_quota
FOR INSERT OR UPDATE OR DELETE ON PAGAMENTO
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_ids t_ids;
    g_count PLS_INTEGER := 0;

    PROCEDURE guardar_id(p_id NUMBER) IS
    BEGIN
        IF p_id IS NOT NULL THEN
            g_count := g_count + 1;
            g_ids(g_count) := p_id;
        END IF;
    END;

    AFTER EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN guardar_id(:NEW.id_quota); END IF;
        IF DELETING OR UPDATING THEN guardar_id(:OLD.id_quota); END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_total NUMBER(12,2);
        v_valor QUOTA.valor%TYPE;
        v_venc  QUOTA.data_vencimento%TYPE;
    BEGIN
        FOR i IN 1..g_count LOOP
            SELECT q.valor, q.data_vencimento,
                   NVL((SELECT SUM(p.valor_pago) FROM PAGAMENTO p
                        WHERE p.id_quota = q.id_quota), 0)
              INTO v_valor, v_venc, v_total
              FROM QUOTA q
             WHERE q.id_quota = g_ids(i);

            UPDATE QUOTA
               SET estado = CASE
                   WHEN v_total >= v_valor THEN 'PAGA'
                   WHEN v_total > 0 THEN 'PARCIAL'
                   WHEN v_venc < TRUNC(SYSDATE) THEN 'ATRASADA'
                   ELSE 'PENDENTE'
               END
             WHERE id_quota = g_ids(i);
        END LOOP;
    END AFTER STATEMENT;
END;
/

-- 3.3 Ao abrir/fechar uma ocupacao, ajusta o estado do apartamento.
CREATE OR REPLACE TRIGGER trg_ocupacao_estado_apart
FOR INSERT OR UPDATE OF data_fim, id_apartamento OR DELETE ON OCUPACAO
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_ids t_ids;
    g_count PLS_INTEGER := 0;

    PROCEDURE guardar_id(p_id NUMBER) IS
    BEGIN
        IF p_id IS NOT NULL THEN
            g_count := g_count + 1;
            g_ids(g_count) := p_id;
        END IF;
    END;

    AFTER EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN guardar_id(:NEW.id_apartamento); END IF;
        IF DELETING OR UPDATING THEN guardar_id(:OLD.id_apartamento); END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_activas NUMBER;
    BEGIN
        FOR i IN 1..g_count LOOP
            SELECT COUNT(*) INTO v_activas
              FROM OCUPACAO
             WHERE id_apartamento = g_ids(i)
               AND data_fim IS NULL;

            UPDATE APARTAMENTO
               SET estado = CASE WHEN v_activas > 0 THEN 'OCUPADO' ELSE 'DISPONIVEL' END
             WHERE id_apartamento = g_ids(i)
               AND estado <> 'MANUTENCAO';
        END LOOP;
    END AFTER STATEMENT;
END;
/

-- =====================================================================
-- 4. PROCEDURES - datas historicas explicitas e validacoes
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_gerar_quota (
    p_id_apartamento IN NUMBER, p_mes_referencia IN DATE,
    p_valor IN NUMBER, p_dia_vencimento IN NUMBER DEFAULT 10
) AS
    v_mes DATE := TRUNC(p_mes_referencia, 'MM');
BEGIN
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001,'Valor da quota deve ser positivo.');
    END IF;
    IF p_dia_vencimento IS NULL OR p_dia_vencimento NOT BETWEEN 1 AND 28 THEN
        RAISE_APPLICATION_ERROR(-20002,'Dia de vencimento entre 1 e 28.');
    END IF;
    INSERT INTO QUOTA (id_apartamento,mes_referencia,valor,data_vencimento,estado)
    VALUES (p_id_apartamento,v_mes,p_valor,v_mes+p_dia_vencimento-1,
       CASE WHEN v_mes+p_dia_vencimento-1 < TRUNC(SYSDATE) THEN 'ATRASADA' ELSE 'PENDENTE' END);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003,'Quota ja existente para apartamento e mes.');
END;
/

CREATE OR REPLACE PROCEDURE sp_registar_pagamento (
    p_id_quota IN NUMBER, p_valor IN NUMBER, p_metodo IN VARCHAR2,
    p_referencia IN VARCHAR2 DEFAULT NULL, p_data_pagamento IN DATE DEFAULT NULL
) AS
    v_quota NUMBER(12,2);
    v_pago NUMBER(12,2);
    v_data DATE := NVL(p_data_pagamento,SYSDATE);
BEGIN
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE_APPLICATION_ERROR(-20010,'Pagamento deve ser positivo.');
    END IF;
    IF v_data > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20013,'Pagamento nao pode ter data futura.');
    END IF;
    SELECT valor INTO v_quota FROM QUOTA WHERE id_quota=p_id_quota FOR UPDATE;
    SELECT NVL(SUM(valor_pago),0) INTO v_pago FROM PAGAMENTO WHERE id_quota=p_id_quota;
    IF p_valor > v_quota-v_pago THEN
        RAISE_APPLICATION_ERROR(-20011,'Pagamento superior ao saldo da quota.');
    END IF;
    INSERT INTO PAGAMENTO (id_quota,data_pagamento,valor_pago,metodo,referencia)
    VALUES (p_id_quota,v_data,p_valor,UPPER(TRIM(p_metodo)),p_referencia);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20012,'Quota inexistente.');
END;
/

CREATE OR REPLACE PROCEDURE sp_abrir_ocorrencia (
    p_id_condominio IN NUMBER, p_id_apartamento IN NUMBER,
    p_titulo IN VARCHAR2, p_descricao IN VARCHAR2,
    p_prioridade IN VARCHAR2, p_data_abertura IN DATE DEFAULT NULL
) AS
BEGIN
    INSERT INTO OCORRENCIA_MANUTENCAO
       (id_condominio,id_apartamento,titulo,descricao,prioridade,estado,data_abertura)
    VALUES (p_id_condominio,p_id_apartamento,p_titulo,p_descricao,
       UPPER(TRIM(p_prioridade)),'ABERTA',NVL(p_data_abertura,SYSDATE));
END;
/

CREATE OR REPLACE PROCEDURE sp_fechar_ocorrencia (
    p_id_ocorrencia IN NUMBER, p_data_fecho IN DATE DEFAULT NULL
) AS
    v_abertura DATE;
    v_fecho DATE := NVL(p_data_fecho,SYSDATE);
BEGIN
    SELECT data_abertura INTO v_abertura FROM OCORRENCIA_MANUTENCAO
    WHERE id_ocorrencia=p_id_ocorrencia AND estado <> 'FECHADA' FOR UPDATE;
    IF v_fecho < v_abertura OR v_fecho > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20021,'Data de fecho invalida.');
    END IF;
    UPDATE OCORRENCIA_MANUTENCAO SET estado='FECHADA',data_fecho=v_fecho
    WHERE id_ocorrencia=p_id_ocorrencia;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20020,'Ocorrencia inexistente ou ja fechada.');
END;
/

CREATE OR REPLACE PROCEDURE sp_registar_despesa (
    p_id_condominio IN NUMBER, p_categoria IN VARCHAR2,
    p_descricao IN VARCHAR2, p_valor IN NUMBER,
    p_data_despesa IN DATE DEFAULT NULL
) AS
BEGIN
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE_APPLICATION_ERROR(-20030,'Despesa deve ter valor positivo.');
    END IF;
    INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa)
    VALUES (p_id_condominio,UPPER(TRIM(p_categoria)),p_descricao,p_valor,
            NVL(p_data_despesa,SYSDATE));
END;
/

-- =====================================================================
-- 5. DADOS DE TESTE REALISTAS - JANEIRO A NOVEMBRO DE 2026
-- Todas as datas armazenadas nos dados iniciais pertencem a 2026.
-- Dados ficticios para fins academicos. Valores em meticais (MT).
-- =====================================================================
INSERT INTO CONDOMINIO (nome,endereco,contacto)
VALUES ('Condominio Zmpeto','Bairro do Zimpeto, Cidade de Maputo, Mocambique','84 500 2026');

INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','01','T1','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','02','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','03','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','04','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','05','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'A','06','T4','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','01','T1','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','02','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','03','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','04','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','05','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'B','06','T4','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','01','T1','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','02','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','03','T2','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','04','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','05','T3','DISPONIVEL');
INSERT INTO APARTAMENTO (id_condominio,bloco,numero,tipologia,estado) VALUES (1,'C','06','T4','DISPONIVEL');

INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Alberto Mucavele','BI2026000001','847000001','condomino01@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Celina Matola','BI2026000002','847000002','condomino02@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Domingos Bila','BI2026000003','847000003','condomino03@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Ermelinda Cossa','BI2026000004','847000004','condomino04@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Filipe Nhantumbo','BI2026000005','847000005','condomino05@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Graca Mondlane','BI2026000006','847000006','condomino06@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Helio Mabote','BI2026000007','847000007','condomino07@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Isabel Sitoe','BI2026000008','847000008','condomino08@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Joao Macuacua','BI2026000009','847000009','condomino09@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Lidia Chissano','BI2026000010','847000010','condomino10@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Mario Nhampossa','BI2026000011','847000011','condomino11@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Nadia Tembe','BI2026000012','847000012','condomino12@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Osvaldo Cuamba','BI2026000013','847000013','condomino13@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Paula Mbanze','BI2026000014','847000014','condomino14@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Quim Ernesto','BI2026000015','847000015','condomino15@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Rosa Nhaca','BI2026000016','847000016','condomino16@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Sergio Mavota','BI2026000017','847000017','condomino17@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Teresa Cossa','BI2026000018','847000018','condomino18@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Ussene Momade','BI2026000019','847000019','condomino19@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Vania Massango','BI2026000020','847000020','condomino20@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Wilson Mabunda','BI2026000021','847000021','condomino21@exemplo.test');
INSERT INTO CONDOMINO (nome,bi_nuit,telefone,email) VALUES ('Yara Mucavele','BI2026000022','847000022','condomino22@exemplo.test');

-- 18 ocupacoes activas e 4 historicas, sem datas anteriores a 2026.
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (1,1,'PROPRIETARIO',DATE '2026-01-04',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (2,2,'PROPRIETARIO',DATE '2026-02-07',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (3,3,'PROPRIETARIO',DATE '2026-03-10',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (4,4,'MORADOR',DATE '2026-04-13',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (5,5,'PROPRIETARIO',DATE '2026-05-16',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (6,6,'PROPRIETARIO',DATE '2026-06-19',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (7,7,'PROPRIETARIO',DATE '2026-01-22',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (8,8,'MORADOR',DATE '2026-02-03',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (9,9,'PROPRIETARIO',DATE '2026-03-06',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (10,10,'PROPRIETARIO',DATE '2026-04-09',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (11,11,'PROPRIETARIO',DATE '2026-05-12',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (12,12,'MORADOR',DATE '2026-06-15',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (13,13,'PROPRIETARIO',DATE '2026-01-18',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (14,14,'PROPRIETARIO',DATE '2026-02-21',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (15,15,'PROPRIETARIO',DATE '2026-03-02',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (16,16,'MORADOR',DATE '2026-04-05',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (17,17,'PROPRIETARIO',DATE '2026-05-08',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (18,18,'PROPRIETARIO',DATE '2026-06-11',NULL);
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (19,1,'MORADOR',DATE '2026-01-02',DATE '2026-02-25');
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (20,5,'MORADOR',DATE '2026-02-01',DATE '2026-04-15');
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (21,10,'MORADOR',DATE '2026-03-03',DATE '2026-05-30');
INSERT INTO OCUPACAO (id_condomino,id_apartamento,tipo_relacao,data_inicio,data_fim) VALUES (22,15,'MORADOR',DATE '2026-01-07',DATE '2026-03-22');

-- 198 quotas (18 apartamentos x 11 meses).
BEGIN
  FOR m IN 1..11 LOOP
    FOR a IN 1..18 LOOP
      sp_gerar_quota(a,ADD_MONTHS(DATE '2026-01-01',m-1),
        CASE WHEN a IN (6,12,18) THEN 4800 WHEN MOD(a,6) IN (4,5) THEN 4200 ELSE 3500 END,10);
    END LOOP;
  END LOOP;
END;
/

-- Pagamentos distribuidos por meses e apartamentos; 2026-11 ate dia 10.
-- Quotas identificadas por (apartamento, mes), sem depender dos IDs.
DECLARE
  v_id NUMBER;
  v_valor NUMBER;
  v_data DATE;
BEGIN
  FOR m IN 1..11 LOOP
    FOR a IN 1..18 LOOP
      SELECT id_quota,valor INTO v_id,v_valor FROM QUOTA
       WHERE id_apartamento=a AND mes_referencia=ADD_MONTHS(DATE '2026-01-01',m-1);
      v_data := ADD_MONTHS(DATE '2026-01-01',m-1)+LEAST(8,MOD(a,7)+2);
      IF m <= 9 THEN
        IF MOD(a+m,7)=0 THEN
          NULL; -- divida integral
        ELSIF MOD(a+m,5)=0 THEN
          sp_registar_pagamento(v_id,ROUND(v_valor*0.4,2),'MPESA','MP-P-'||m||'-'||a,v_data);
        ELSE
          sp_registar_pagamento(v_id,v_valor,'TRANSFERENCIA','TRX-P-'||m||'-'||a,v_data);
        END IF;
      ELSIF m=10 THEN
        IF MOD(a,4)=0 THEN
          sp_registar_pagamento(v_id,ROUND(v_valor*0.5,2),'EMOLA','EM-O-'||a,v_data);
        ELSIF MOD(a,3)<>0 THEN
          sp_registar_pagamento(v_id,v_valor,'DEPOSITO','DEP-O-'||a,v_data);
        END IF;
      ELSE
        IF MOD(a,3)=0 THEN
          sp_registar_pagamento(v_id,v_valor,'MPESA','MP-N-'||a,DATE '2026-11-08');
        ELSIF MOD(a,4)=0 THEN
          sp_registar_pagamento(v_id,ROUND(v_valor*0.3,2),'NUMERARIO','NUM-N-'||a,DATE '2026-11-09');
        END IF;
      END IF;
    END LOOP;
  END LOOP;
END;
/

INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'LIMPEZA','Limpeza das areas comuns - mes 01',9625,DATE '2026-01-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 01',6525,DATE '2026-01-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 01',8225,DATE '2026-01-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 01',14625,DATE '2026-01-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 02',6650,DATE '2026-02-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 02',8350,DATE '2026-02-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 02',14750,DATE '2026-02-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 02',4050,DATE '2026-02-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 03',8475,DATE '2026-03-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 03',14875,DATE '2026-03-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 03',4175,DATE '2026-03-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 03',3075,DATE '2026-03-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 04',15000,DATE '2026-04-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 04',4300,DATE '2026-04-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 04',3200,DATE '2026-04-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'SEGURANCA','Vigilancia e controlo de acessos - mes 04',27000,DATE '2026-04-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 05',4425,DATE '2026-05-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 05',3325,DATE '2026-05-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'SEGURANCA','Vigilancia e controlo de acessos - mes 05',27125,DATE '2026-05-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'LIMPEZA','Limpeza das areas comuns - mes 05',10125,DATE '2026-05-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 06',3450,DATE '2026-06-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'SEGURANCA','Vigilancia e controlo de acessos - mes 06',27250,DATE '2026-06-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'LIMPEZA','Limpeza das areas comuns - mes 06',10250,DATE '2026-06-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 06',7150,DATE '2026-06-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'SEGURANCA','Vigilancia e controlo de acessos - mes 07',27375,DATE '2026-07-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'LIMPEZA','Limpeza das areas comuns - mes 07',10375,DATE '2026-07-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 07',7275,DATE '2026-07-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 07',8975,DATE '2026-07-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'LIMPEZA','Limpeza das areas comuns - mes 08',10500,DATE '2026-08-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 08',7400,DATE '2026-08-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 08',9100,DATE '2026-08-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 08',15500,DATE '2026-08-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'AGUA','Abastecimento de agua comum - mes 09',7525,DATE '2026-09-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 09',9225,DATE '2026-09-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 09',15625,DATE '2026-09-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 09',4925,DATE '2026-09-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ENERGIA','Iluminacao e energia comum - mes 10',9350,DATE '2026-10-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 10',15750,DATE '2026-10-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 10',5050,DATE '2026-10-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 10',3950,DATE '2026-10-18');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'MANUTENCAO','Reparacoes preventivas - mes 11',15875,DATE '2026-11-03');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'ADMINISTRACAO','Material de expediente - mes 11',5175,DATE '2026-11-08');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'OUTROS','Material diverso para o condominio - mes 11',4075,DATE '2026-11-13');
INSERT INTO DESPESA (id_condominio,categoria,descricao,valor,data_despesa) VALUES (1,'SEGURANCA','Vigilancia e controlo de acessos - mes 11',27875,DATE '2026-11-18');

-- 22 ocorrencias, com abertas, em curso e fechadas.
BEGIN sp_abrir_ocorrencia(1,1,'Fuga de agua no apartamento','Registo de manutencao 01 - fuga de agua no apartamento.','MEDIA',DATE '2026-01-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,2,'Falha na iluminacao do corredor','Registo de manutencao 02 - falha na iluminacao do corredor.','ALTA',DATE '2026-02-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,3,'Portao automatico com avaria','Registo de manutencao 03 - portao automatico com avaria.','URGENTE',DATE '2026-03-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,4,'Infiltracao na parede','Registo de manutencao 04 - infiltracao na parede.','BAIXA',DATE '2026-04-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,NULL,'Intercomunicador sem sinal','Registo de manutencao 05 - intercomunicador sem sinal.','MEDIA',DATE '2026-05-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,6,'Limpeza do reservatorio','Registo de manutencao 06 - limpeza do reservatorio.','ALTA',DATE '2026-06-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,7,'Elevador com ruido','Registo de manutencao 07 - elevador com ruido.','URGENTE',DATE '2026-07-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,8,'Reparacao do pavimento','Registo de manutencao 08 - reparacao do pavimento.','BAIXA',DATE '2026-08-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,9,'Problema na fechadura','Registo de manutencao 09 - problema na fechadura.','MEDIA',DATE '2026-09-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,NULL,'Falha de energia comum','Registo de manutencao 10 - falha de energia comum.','ALTA',DATE '2026-10-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,11,'Jardim com irrigacao avariada','Registo de manutencao 11 - jardim com irrigacao avariada.','URGENTE',DATE '2026-11-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,12,'Tubagem da area comum','Registo de manutencao 12 - tubagem da area comum.','BAIXA',DATE '2026-01-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,13,'Verificacao de extintores','Registo de manutencao 13 - verificacao de extintores.','MEDIA',DATE '2026-02-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,14,'Ruido na bomba de agua','Registo de manutencao 14 - ruido na bomba de agua.','ALTA',DATE '2026-03-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,NULL,'Pintura do corredor','Registo de manutencao 15 - pintura do corredor.','URGENTE',DATE '2026-04-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,16,'Fuga de agua na garagem','Registo de manutencao 16 - fuga de agua na garagem.','BAIXA',DATE '2026-05-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,17,'Reparacao de candeeiros','Registo de manutencao 17 - reparacao de candeeiros.','MEDIA',DATE '2026-06-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,18,'Inspeccao da rede electrica','Registo de manutencao 18 - inspeccao da rede electrica.','ALTA',DATE '2026-07-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,1,'Porta de emergencia','Registo de manutencao 19 - porta de emergencia.','URGENTE',DATE '2026-08-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,NULL,'Avaria no sistema de acesso','Registo de manutencao 20 - avaria no sistema de acesso.','BAIXA',DATE '2026-09-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,3,'Revisao da cobertura','Registo de manutencao 21 - revisao da cobertura.','MEDIA',DATE '2026-10-05'); END;
/
BEGIN sp_abrir_ocorrencia(1,4,'Inspeccao do reservatorio','Registo de manutencao 22 - inspeccao do reservatorio.','ALTA',DATE '2026-11-05'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=1;
BEGIN sp_fechar_ocorrencia(3,DATE '2026-03-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=4;
BEGIN sp_fechar_ocorrencia(6,DATE '2026-06-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=7;
BEGIN sp_fechar_ocorrencia(9,DATE '2026-09-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=10;
BEGIN sp_fechar_ocorrencia(12,DATE '2026-01-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=13;
BEGIN sp_fechar_ocorrencia(15,DATE '2026-04-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=16;
BEGIN sp_fechar_ocorrencia(18,DATE '2026-07-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=19;
BEGIN sp_fechar_ocorrencia(21,DATE '2026-10-12'); END;
/
UPDATE OCORRENCIA_MANUTENCAO SET estado='EM_CURSO' WHERE id_ocorrencia=22;

-- Avisos mensais; pares dirigidos a blocos, impares gerais.
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 01/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 01.',DATE '2026-01-02',DATE '2026-01-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 02/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 02.',DATE '2026-02-02',DATE '2026-02-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 03/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 03.',DATE '2026-03-02',DATE '2026-03-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 04/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 04.',DATE '2026-04-02',DATE '2026-04-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 05/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 05.',DATE '2026-05-02',DATE '2026-05-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 06/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 06.',DATE '2026-06-02',DATE '2026-06-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 07/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 07.',DATE '2026-07-02',DATE '2026-07-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 08/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 08.',DATE '2026-08-02',DATE '2026-08-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 09/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 09.',DATE '2026-09-02',DATE '2026-09-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 10/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 10.',DATE '2026-10-02',DATE '2026-10-25');
INSERT INTO AVISO (id_condominio,titulo,mensagem,data_publicacao,validade) VALUES (1,'Comunicado mensal 11/2026','Informacoes sobre pagamentos, manutencao e servicos do Condominio Zmpeto no mes 11.',DATE '2026-11-02',DATE '2026-11-25');
-- Avisos pares destinados aos apartamentos do Bloco A.
INSERT INTO AVISO_DESTINATARIO (id_aviso,id_apartamento)
SELECT av.id_aviso, ap.id_apartamento FROM AVISO av CROSS JOIN APARTAMENTO ap
WHERE MOD(av.id_aviso,2)=0 AND ap.bloco='A';

COMMIT;

-- =====================================================================
-- 6. VALIDACAO E CONSULTAS DE DEMONSTRACAO
-- =====================================================================
PROMPT === CONTAGEM DE REGISTOS NAS 10 TABELAS ===
SELECT 'CONDOMINIO' tabela,COUNT(*) total FROM CONDOMINIO UNION ALL
SELECT 'APARTAMENTO',COUNT(*) FROM APARTAMENTO UNION ALL
SELECT 'CONDOMINO',COUNT(*) FROM CONDOMINO UNION ALL
SELECT 'OCUPACAO',COUNT(*) FROM OCUPACAO UNION ALL
SELECT 'QUOTA',COUNT(*) FROM QUOTA UNION ALL
SELECT 'PAGAMENTO',COUNT(*) FROM PAGAMENTO UNION ALL
SELECT 'DESPESA',COUNT(*) FROM DESPESA UNION ALL
SELECT 'OCORRENCIA_MANUTENCAO',COUNT(*) FROM OCORRENCIA_MANUTENCAO UNION ALL
SELECT 'AVISO',COUNT(*) FROM AVISO UNION ALL
SELECT 'AVISO_DESTINATARIO',COUNT(*) FROM AVISO_DESTINATARIO;

PROMPT === DISTRIBUICAO DE QUOTAS POR ESTADO ===
SELECT estado,COUNT(*) quantidade FROM QUOTA GROUP BY estado ORDER BY estado;

PROMPT === SALDOS DE QUOTAS POR APARTAMENTO ===
SELECT a.bloco,a.numero,COUNT(q.id_quota) total_quota,
       SUM(q.valor) valor_devido,NVL(SUM(pg.total_pago),0) valor_pago,
       SUM(q.valor)-NVL(SUM(pg.total_pago),0) saldo
FROM APARTAMENTO a JOIN QUOTA q ON q.id_apartamento=a.id_apartamento
LEFT JOIN (SELECT id_quota,SUM(valor_pago) total_pago FROM PAGAMENTO GROUP BY id_quota) pg
 ON pg.id_quota=q.id_quota
GROUP BY a.bloco,a.numero ORDER BY a.bloco,a.numero;

PROMPT === RECEITAS POR MES ===
SELECT TO_CHAR(TRUNC(data_pagamento,'MM'),'YYYY-MM') mes,
       COUNT(*) pagamentos,SUM(valor_pago) receitas_mt
FROM PAGAMENTO GROUP BY TRUNC(data_pagamento,'MM')
ORDER BY TRUNC(data_pagamento,'MM');

PROMPT === DESPESAS POR MES ===
SELECT TO_CHAR(TRUNC(data_despesa,'MM'),'YYYY-MM') mes,
       COUNT(*) despesas,SUM(valor) total_mt
FROM DESPESA GROUP BY TRUNC(data_despesa,'MM')
ORDER BY TRUNC(data_despesa,'MM');

PROMPT === OCORRENCIAS POR ESTADO ===
SELECT estado,COUNT(*) quantidade FROM OCORRENCIA_MANUTENCAO GROUP BY estado;

PROMPT === OCUPACOES ACTIVAS E HISTORICAS ===
SELECT CASE WHEN data_fim IS NULL THEN 'ACTIVA' ELSE 'HISTORICA' END situacao,
       COUNT(*) quantidade FROM OCUPACAO
GROUP BY CASE WHEN data_fim IS NULL THEN 'ACTIVA' ELSE 'HISTORICA' END;

PROMPT === DATAS FORA DO INTERVALO ESPERADO (DEVEM DAR ZERO) ===
SELECT 'OCUPACAO' origem,COUNT(*) fora FROM OCUPACAO
WHERE data_inicio NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
 OR (data_fim IS NOT NULL AND data_fim NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11')
UNION ALL SELECT 'QUOTA',COUNT(*) FROM QUOTA
WHERE mes_referencia NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
 OR data_vencimento NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
UNION ALL SELECT 'PAGAMENTO',COUNT(*) FROM PAGAMENTO
WHERE data_pagamento NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
UNION ALL SELECT 'DESPESA',COUNT(*) FROM DESPESA
WHERE data_despesa NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
UNION ALL SELECT 'MANUTENCAO',COUNT(*) FROM OCORRENCIA_MANUTENCAO
WHERE data_abertura NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
 OR (data_fecho IS NOT NULL AND data_fecho NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11')
UNION ALL SELECT 'AVISO',COUNT(*) FROM AVISO
WHERE data_publicacao NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11'
 OR (validade IS NOT NULL AND validade NOT BETWEEN DATE '2026-01-01' AND DATE '2026-11-11');

PROMPT === OBJECTOS INVALIDOS (DEVEM DAR ZERO) ===
SELECT object_name,object_type,status FROM USER_OBJECTS
WHERE status='INVALID' ORDER BY object_type,object_name;

PROMPT === FIM DA EXECUCAO ===
