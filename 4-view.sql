CREATE OR REPLACE  VIEW INVOICE_CPL (INVOICE_ID, INVOICE_REFERENCE, INVOICE_DATE, INVOICE_STATUS, INVOICE_HOLD_REASON, INVOICE_AMOUNT, INVOICE_DESCRIPTION, ORDER_LINE_ID, ORDER_LINE_REF, ORDER_REF, ORDER_ID) AS 
  SELECT xi.INVOICE_ID,xi.INVOICE_REFERENCE,xi.INVOICE_DATE,xis.STATUS_NAME ,xi.INVOICE_HOLD_REASON,xi.INVOICE_AMOUNT,xi.INVOICE_DESCRIPTION,xi.ORDER_LINE_ID ,
      		xol.order_line_ref,
      		xo.order_ref,
      		xo.order_id
      		FROM XXBCM_INVOICES xi,
      		XXBCM_ORDER_LINE xol,
      		XXBCM_ORDERS xo ,
      		XXBCM_INVOICE_STATUS xis 
      		WHERE xi.order_line_id = xol.order_line_id (+)
      		AND xol.order_id= xo.order_id(+)
      		AND xis.STATUS_ID(+)  = xi.STATUS_ID; 
      	
CREATE OR REPLACE  VIEW ORDER_INVOICE_GRP (ORDER_REF, INVOICE_AMOUNT, INVOICE_REFERENCE, INVOICE_REFERENCES_CONCAT) AS 
  SELECT 
       v.order_ref,
       sum(nvl(invoice_amount,0)) AS invoice_amount,
       SUBSTR(min(v.invoice_reference),1,9) AS invoice_reference,
       LISTAGG( v.INVOICE_REFERENCE, '|') WITHIN GROUP (ORDER BY INVOICE_DATE) AS INVOICE_REFERENCES_concat
       FROM INVOICE_CPL v
       GROUP BY order_ref 
;
      	
CREATE OR REPLACE  VIEW FULL_DETAILS_CPL (ORDER_REFERENCE, ORDER_DATE, ORDER_DATE_DATE, ORDER_DESCRIPTION, ORDER_TOTAL_AMOUNT, ORDER_TOTAL_AMOUNT_NBR, ORDER_STATUS, SUPPLIER_NAME, INVOICE_REFERENCE, INVOICE_AMOUNT, ACTION, SUPPLIER_ID, INVOICE_REFERENCES_CONCAT) AS 
  SELECT 
      	TO_NUMBER(REGEXP_SUBSTR(xo.order_ref, '\d+')) AS order_reference,
      	TO_CHAR(xo.order_date, 'MON-YYYY') AS ORDER_date,
      	xo.order_date AS order_date_date,
      	ORDER_description,
      	 TO_CHAR(order_total_amount, 'FM999,999,999.00')
        AS 	order_total_amount,
        order_total_amount AS order_total_amount_nbr,
      	xos.STATUS_NAME as order_status,
      	INITCAP(xs.supplier_name) AS supplier_name,
      	vgo.invoice_reference,
         TO_CHAR(vgo.invoice_amount, 'FM999,999,999.00') AS invoice_amount,
         get_invoice_action(xo.order_id) AS ACTION ,
         xs.supplier_id,
         INVOICE_REFERENCES_concat
      	FROM 
      	XXBCM_ORDERS xo,
      	XXBCM_SUPPLIERS xs ,
      	ORDER_INVOICE_GRP vgo,
      	XXBCM_ORDER_STATUS xos 
      	WHERE 
      		xo.supplier_id=xs.supplier_id(+)
      		AND xo.order_ref= vgo.order_ref (+)
      		AND xos.STATUS_ID (+) = xo.STATUS_ID 
      	ORDER BY xo.order_date desc
      	;
      
   

-- 4  
CREATE OR REPLACE VIEW get_order_summary AS
    SELECT 
        TO_NUMBER(REGEXP_SUBSTR(xo.ORDER_REF, '\d+')) AS ORDER_REFERENCE,
        TO_CHAR(xo.ORDER_DATE, 'MON-YYYY', 'NLS_DATE_LANGUAGE = ENGLISH') AS ORDER_PERIOD,
		xs.SUPPLIER_NAME ,
        TO_CHAR(xo.ORDER_TOTAL_AMOUNT, 'FM999,999,999.00') AS ORDER_TOTAL_AMOUNT,
        xo.ORDER_TOTAL_AMOUNT AS ORDER_TOTAL_AMOUNT_NBR,
        xos.STATUS_NAME AS ORDER_STATUS,
        vgo.INVOICE_REFERENCE,
        TO_CHAR(vgo.INVOICE_AMOUNT, 'FM999,999,999.00') AS INVOICE_AMOUNT,
        get_invoice_action(xo.ORDER_ID) AS ACTION
    FROM 
        XXBCM_ORDERS xo
    LEFT JOIN 
        XXBCM_SUPPLIERS xs ON xo.SUPPLIER_ID = xs.SUPPLIER_ID
    LEFT JOIN 
        (SELECT 
            ORDER_REF, 
            SUM(NVL(INVOICE_AMOUNT, 0)) AS INVOICE_AMOUNT, 
            MIN(INVOICE_REFERENCE) AS INVOICE_REFERENCE,
            LISTAGG(INVOICE_REFERENCE, '|') WITHIN GROUP (ORDER BY INVOICE_DATE) AS INVOICE_REFERENCES_CONCAT
        FROM 
            INVOICE_CPL 
        GROUP BY ORDER_REF) vgo ON xo.ORDER_REF = vgo.ORDER_REF
    LEFT JOIN 
        XXBCM_ORDER_STATUS xos ON xo.STATUS_ID = xos.STATUS_ID
    ORDER BY 
        xo.ORDER_DATE DESC;

  
       
   -- 5 
CREATE OR REPLACE VIEW get_second_highest_order AS
    SELECT 
        ORDER_REFERENCE,
        TO_CHAR(ORDER_DATE_DATE, 'MON-YYYY', 'NLS_DATE_LANGUAGE = ENGLISH') AS ORDER_DATE,
        SUPPLIER_NAME,
        ORDER_TOTAL_AMOUNT,
        ORDER_STATUS,
        INVOICE_REFERENCES_CONCAT AS INVOICE_REFERENCES
    FROM 
        (SELECT 
            vg.*,
            RANK() OVER (ORDER BY ORDER_TOTAL_AMOUNT DESC) AS rnk
        FROM 
            FULL_DETAILS_CPL vg)
    WHERE rnk = 2;

-- 6

CREATE OR REPLACE VIEW get_supplier_order_summary
AS
    SELECT 
        xs.SUPPLIER_NAME,
        xs.SUPP_CONTACT_NAME,
        refractor_contact(xs.SUPP_CONTACT_1) AS SUPP_CONTACT_1,
        refractor_contact(xs.SUPP_CONTACT_2) AS SUPP_CONTACT_2,
        vog.TOTAL_ORDER AS TOTAL_ORDERS,
        vog.ORDER_TOTAL_AMOUNT AS ORDER_TOTAL_AMOUNT
    FROM 
        XXBCM_SUPPLIERS xs
    JOIN 
        (SELECT 
            SUPPLIER_ID,
            SUM(ORDER_TOTAL_AMOUNT_NBR) AS ORDER_TOTAL_AMOUNT,
            COUNT(ORDER_REFERENCE) AS TOTAL_ORDER
        FROM 
            (SELECT 
                TO_NUMBER(REGEXP_SUBSTR(xo.ORDER_REF, '\d+')) AS ORDER_REFERENCE,
                TO_CHAR(xo.ORDER_DATE, 'MON-YYYY') AS ORDER_DATE,
                xo.ORDER_DATE AS ORDER_DATE_DATE,
                xo.ORDER_DESCRIPTION,
                TO_CHAR(xo.ORDER_TOTAL_AMOUNT, 'FM999,999,999.00') AS ORDER_TOTAL_AMOUNT,
                xo.ORDER_TOTAL_AMOUNT AS ORDER_TOTAL_AMOUNT_NBR,
                xos.STATUS_NAME AS ORDER_STATUS,
                INITCAP(xs.SUPPLIER_NAME) AS SUPPLIER_NAME,
                vgo.INVOICE_REFERENCE,
                TO_CHAR(vgo.INVOICE_AMOUNT, 'FM999,999,999.00') AS INVOICE_AMOUNT,
                get_invoice_action(xo.ORDER_ID) AS ACTION,
                xs.SUPPLIER_ID,
                vgo.INVOICE_REFERENCES_CONCAT
            FROM 
                XXBCM_ORDERS xo
            LEFT JOIN 
                XXBCM_SUPPLIERS xs ON xo.SUPPLIER_ID = xs.SUPPLIER_ID
            LEFT JOIN 
                (SELECT 
                    ORDER_REF, 
                    SUM(NVL(INVOICE_AMOUNT, 0)) AS INVOICE_AMOUNT, 
                    MIN(INVOICE_REFERENCE) AS INVOICE_REFERENCE,
                    LISTAGG(INVOICE_REFERENCE, '|') WITHIN GROUP (ORDER BY INVOICE_DATE) AS INVOICE_REFERENCES_CONCAT
                FROM 
                    INVOICE_CPL 
                GROUP BY ORDER_REF) vgo ON xo.ORDER_REF = vgo.ORDER_REF
            LEFT JOIN 
                XXBCM_ORDER_STATUS xos ON xo.STATUS_ID = xos.STATUS_ID
            WHERE 
                xo.ORDER_DATE BETWEEN TO_DATE('2022-01-01', 'YYYY-MM-DD') AND TO_DATE('2022-08-31', 'YYYY-MM-DD'))
        GROUP BY SUPPLIER_ID) vog ON xs.SUPPLIER_ID = vog.SUPPLIER_ID;


      