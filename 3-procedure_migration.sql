ALTER SESSION SET NLS_DATE_LANGUAGE = 'ENGLISH';
    
CREATE OR REPLACE PROCEDURE insert_suppliers AS
BEGIN
    INSERT INTO XXBCM_SUPPLIERS
    (
        SUPPLIER_NAME,
        SUPP_CONTACT_NAME,
        SUPP_ADDRESS,
        SUPP_CONTACT_1,
        SUPP_CONTACT_2,
        SUPP_EMAIL
    )
    SELECT
        DISTINCT SUPPLIER_NAME,
        SUPP_CONTACT_NAME,
        SUPP_ADDRESS,
        REPLACE(REPLACE((REGEXP_SUBSTR(convert_and_validate_contact(SUPP_CONTACT_NUMBER), '[^,]+', 1, 1)), ' ', ''), '.', '') AS contact1,
        REPLACE(REPLACE((REGEXP_SUBSTR(convert_and_validate_contact(SUPP_CONTACT_NUMBER), '[^,]+', 1, 2)), ' ', ''), '.', '') AS contact2,
        SUPP_EMAIL
    FROM
        XXBCM_ORDER_MGT;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Erreur lors de l''insertion des fournisseurs: ' || SQLERRM);
END;
/


CREATE OR REPLACE PROCEDURE insert_orders AS
BEGIN
    INSERT INTO XXBCM_ORDERS
    (
        ORDER_REF,
        ORDER_DATE,
        ORDER_DESCRIPTION,
        STATUS_ID ,
        ORDER_TOTAL_AMOUNT,
        SUPPLIER_ID
    )
    SELECT
        ord.ORDER_REF,
        convert_to_date(ord.ORDER_DATE),
        ord.ORDER_DESCRIPTION,
        status.STATUS_ID,  
        convert_and_valide_montant(ord.ORDER_TOTAL_AMOUNT),
        (
            SELECT SUPPLIER_ID
            FROM XXBCM_SUPPLIERS xs
            WHERE xs.SUPPLIER_NAME = ord.SUPPLIER_NAME
        )
    FROM
        XXBCM_ORDER_MGT ord
    JOIN
        XXBCM_ORDER_STATUS status ON ord.ORDER_STATUS  = status.STATUS_NAME
    WHERE
        LENGTH(ord.ORDER_REF) = 5;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'Erreur lors de l''insertion des commandes: ' || SQLERRM);
END;
/


CREATE OR REPLACE PROCEDURE insert_order_lines AS
BEGIN
    INSERT INTO XXBCM_ORDER_LINE
    (
        ORDER_LINE_REF,
        ORDER_ID,
        ORDER_DESCRIPTION,
        STATUS_ID,  
        ORDER_LINE_AMOUNT
    )
    SELECT
        ord.ORDER_REF,
        (
            SELECT ORDER_ID
            FROM XXBCM_ORDERS xs
            WHERE xs.ORDER_REF = SUBSTR(ord.ORDER_REF, 1, 5)
        ),
        ord.ORDER_DESCRIPTION,
        (
            SELECT status.STATUS_ID
            FROM XXBCM_ORDER_STATUS status
            WHERE status.STATUS_NAME = ord.ORDER_STATUS
        ) AS STATUS_ID,  
        convert_and_valide_montant(ord.ORDER_LINE_AMOUNT)
    FROM
        XXBCM_ORDER_MGT ord
    WHERE
        LENGTH(ord.ORDER_REF) > 5;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Erreur lors de l''insertion des lignes de commande: ' || SQLERRM);
END;
/


CREATE OR REPLACE PROCEDURE insert_invoices AS
BEGIN
    INSERT INTO XXBCM_INVOICES
    (
        INVOICE_REFERENCE,
        INVOICE_DATE,
        STATUS_ID ,
        INVOICE_HOLD_REASON,
        INVOICE_AMOUNT,
        INVOICE_DESCRIPTION,
        ORDER_LINE_ID 
    )
    SELECT 
        ord.INVOICE_REFERENCE,
        convert_to_date(ord.INVOICE_DATE),
        S.STATUS_ID,
        ord.INVOICE_HOLD_REASON,
        convert_and_valide_montant(ord.INVOICE_AMOUNT),
        ord.INVOICE_DESCRIPTION,
        (
            SELECT MAX(xs.ORDER_LINE_ID)
            FROM XXBCM_ORDER_LINE xs
            WHERE xs.ORDER_LINE_REF = ord.ORDER_REF
        )
    FROM
        XXBCM_ORDER_MGT ord
    LEFT JOIN 
        XXBCM_INVOICE_STATUS S
    ON 
        ord.INVOICE_STATUS = S.STATUS_NAME ;

    -- Supprimer les factures sans référence de ligne de commande
    DELETE FROM XXBCM_INVOICES WHERE ORDER_LINE_ID IS NULL;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004, 'Erreur lors de l''insertion des factures: ' || SQLERRM);
END;
/


CREATE OR REPLACE PROCEDURE migrate_data AS
BEGIN
    insert_suppliers;
    insert_orders;
    insert_order_lines;
    insert_invoices;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20005, 'Erreur lors de la migration des données: ' || SQLERRM);
END;
/


BEGIN
    migrate_data;
END;
/

