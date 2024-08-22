CREATE OR REPLACE FUNCTION convert_and_validate_contact(param_contact IN VARCHAR2) RETURN VARCHAR2 IS
    contact_formatted VARCHAR2(50);
BEGIN
    contact_formatted := REGEXP_REPLACE(param_contact, '[sS]', '5');
    contact_formatted := REGEXP_REPLACE(contact_formatted, '[lI]', '1');
    contact_formatted := REGEXP_REPLACE(contact_formatted, '[oO]', '0');
    RETURN contact_formatted;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'INVALID CONTACT';
END;

CREATE OR REPLACE FUNCTION convert_and_valide_montant(param_montant IN VARCHAR2) RETURN NUMBER IS
    montant_transforme VARCHAR2(4000);
    final_value NUMBER;
BEGIN
    montant_transforme := REGEXP_REPLACE(param_montant, '([sS])', '5');  
    montant_transforme := REGEXP_REPLACE(montant_transforme, '([Il])', '1');  
    montant_transforme := REGEXP_REPLACE(montant_transforme, '([oO])', '0');  
    montant_transforme := REPLACE(montant_transforme, ',', ''); 
    BEGIN
        final_value := TO_NUMBER(montant_transforme);
    EXCEPTION
        WHEN VALUE_ERROR THEN
            final_value := NULL;  
    END;

    RETURN final_value;
END;
/


CREATE OR REPLACE FUNCTION get_invoice_action(param_order_id IN NUMBER) RETURN VARCHAR2 IS
    status_id_pending NUMBER;
    status_id_paid NUMBER;
    invoice_action VARCHAR2(20);
BEGIN
    SELECT STATUS_ID INTO status_id_pending FROM XXBCM_INVOICE_STATUS WHERE STATUS_NAME = 'Pending';
    SELECT STATUS_ID INTO status_id_paid FROM XXBCM_INVOICE_STATUS WHERE STATUS_NAME = 'Paid';

    SELECT CASE
             WHEN COUNT(CASE WHEN STATUS_ID = status_id_pending THEN 1 END) > 0 THEN 'To follow up'
             WHEN COUNT(CASE WHEN STATUS_ID IS NULL OR STATUS_ID = '' THEN 1 END) > 0 THEN 'To verify'
             WHEN COUNT(CASE WHEN STATUS_ID <> status_id_paid THEN 1 END) = 0 AND COUNT(*) > 0 THEN 'OK'
             ELSE 'Unknown Status'
           END
    INTO invoice_action
    FROM XXBCM_INVOICES
    WHERE ORDER_LINE_ID IN (SELECT ORDER_LINE_ID FROM XXBCM_ORDER_LINE WHERE ORDER_ID = param_order_id);

    RETURN invoice_action;
END;
/

CREATE OR REPLACE FUNCTION isemail(email IN VARCHAR2) RETURN BOOLEAN IS
    v_is_valid BOOLEAN := FALSE;
BEGIN
    v_is_valid := REGEXP_LIKE(email,
        '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$','i');
    RETURN v_is_valid;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
/


CREATE OR REPLACE FUNCTION convert_to_date(param_date IN VARCHAR2) RETURN DATE IS
    clean_date VARCHAR2(30);
    converted_date DATE;
    formats SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('DD-MON-YYYY', 'DD-MMM-YYYY', 'DD-MM-YYYY', 'DD-M-YYYY', 'DD/MM/YYYY', 'DD-MM-YYYY');
BEGIN
    clean_date := TRIM(REPLACE(param_date, '/', '-'));

    FOR i IN 1..formats.COUNT LOOP
        BEGIN
            converted_date := TO_DATE(clean_date, formats(i));
            RETURN converted_date;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;

    RAISE_APPLICATION_ERROR(-20001, 'Invalid date format: ' || param_date);
END;
/

CREATE OR REPLACE FUNCTION format_contact_number(param_number IN VARCHAR2) 
RETURN VARCHAR2 IS
    formatted_number VARCHAR2(20);
BEGIN
    IF param_number IS NULL THEN 
        RETURN '';

    ELSIF LENGTH(param_number) = 7 THEN
        formatted_number := SUBSTR(param_number, 1, 3) || '-' || SUBSTR(param_number, 4, 4);
        RETURN formatted_number;

    ELSIF LENGTH(param_number) = 8 THEN
        formatted_number := SUBSTR(param_number, 1, 4) || '-' || SUBSTR(param_number, 5, 4);
        RETURN formatted_number;

    ELSE  
        RAISE_APPLICATION_ERROR(-20001, 'Numéro non valide : ' || param_number);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Erreur imprévue : ' || SQLERRM);
END;
/



