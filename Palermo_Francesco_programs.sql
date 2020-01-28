/********************************************************** 
****** Stored Programs for Assn.2, 2019 *******************
********** Francesco Palermo and 45539669 ************************
******************* Date **********************************
** I declare that the code provided below is my own work **
******* Any help received is duely acknowledged here ******
**********************************************************/

/********* Trigger TR_OVERDUE ************/


drop trigger if exists tr_overdue;


delimiter //
CREATE TRIGGER tr_overdue 
BEFORE UPDATE ON invoice 
FOR EACH ROW


    BEGIN
    DECLARE msg VARCHAR(250);
    set msg = CONCAT('Invoice with number: ',NEW.INVOICENO,' is now overdue!');
	
    IF (NEW.STATUS ='OVERDUE') THEN
		-- INSERTING ROWS TO THE TABLE alert
		INSERT INTO alerts (message_date,origin,message) VALUES (now(),current_user(),msg);
    
    END IF;
    END//
DELIMITER ;

/************* Helper Functions/Procedures used, two functions for example ****************/

drop function if exists rate_on_date;

delimiter //
CREATE FUNCTION rate_on_date(staff_id INT, given_date DATE) 
RETURNS FLOAT
DETERMINISTIC
BEGIN
	-- declare a local variable that store the total hour_rate on a given date	
	  DECLARE hourly_rate FLOAT DEFAULT 0;	

	-- return the total salary of a given staff (staff_id) on any particular date (given_date)
	  
		SELECT sg.HOURLYRATE INTO hourly_rate
		FROM workson wo, staffongrade sog, salarygrade sg
		WHERE wo.STAFFNO = sog.STAFFNO AND sog.GRADE = sg.GRADE
				AND wo.STAFFNO = staff_id AND wo.WDATE = given_date AND given_date >= sog.STARTDATE and (given_date <= sog.FINISHDATE OR sog.FINISHDATE IS NULL);

      RETURN hourly_rate;

END //
DELIMITER ;

-- create function cost_of_campaign (camp_id int) returns float
-- retuens the total cost incurred due to any given campaigh (camp_id) 
drop function if exists cost_of_campaign ;
delimiter //
CREATE FUNCTION cost_of_campaign(camp_id INT) 
RETURNS FLOAT
DETERMINISTIC
BEGIN
	
	-- declare a local variable that store the total cost of a campaign
    DECLARE v_finito FLOAT DEFAULT 0;
    DECLARE costo_totale FLOAT DEFAULT 0;	
    DECLARE c_hour FLOAT DEFAULT 0;
    DECLARE c_rate FLOAT DEFAULT 0;
    
    -- declare a cursor
    DECLARE hour_rate CURSOR FOR
    SELECT  HOUR,rate_on_date(STAFFNO,WDATE)
	FROM workson
    WHERE CAMPAIGN_NO = camp_id;	
    -- delare the handler
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finito = 1;
     
	-- OPEN THE CURSOR AND LOOP TO GET THE TOTAL 
	OPEN hour_rate;      
	WHILE (v_finito=0) DO

			FETCH hour_rate INTO c_hour,c_rate;
            
            IF (v_finito=0) THEN
			    SET costo_totale = costo_totale+(c_hour*c_rate);
				
			END IF;
      
	END WHILE;
	CLOSE hour_rate;
      
	RETURN costo_totale;


END//
delimiter ;


/************ Procedure SP_FINISH_CAMPAIGN******************/


drop procedure if exists sp_finish_campaign;
delimiter //

CREATE PROCEDURE sp_finish_campaign (in c_title varchar(30))


BEGIN
	DECLARE v_campaign_count INT DEFAULT 0;
    DECLARE v_costof_camp FLOAT DEFAULT 0;

	-- count the number of campaign with the supplied c_title
	-- the count will be 1 if if the campaign exists
	SELECT COUNT(*) INTO v_campaign_count
    FROM campaign 
    WHERE TITLE=c_title;
    
    -- if the campaign exists update CAMPAIGNFINISHDATE AND ACTUALCOST
    IF (v_campaign_count = 1) THEN
		-- UPDATE THE campaignfinishdate TO THE CURRENT DATE
        UPDATE campaign
        SET CAMPAIGNFINISHDATE = now()
        WHERE TITLE = c_title;
        -- UPDATE THE actual cost 
        SELECT cost_of_campaign(CAMPAIGN_NO) INTO v_costof_camp
        FROM campaign
        WHERE TITLE=c_title;
        
		UPDATE campaign
        SET ACTUALCOST = v_costof_camp
        WHERE TITLE = c_title;
    ELSE
		SIGNAL SQLSTATE '45000'
        --  which means “unhandled user-defined exception.”
        SET MESSAGE_TEXT = 'ERROR! Campaign title does not exist';
        
    END IF;
 


END//
delimiter ;


/************ Procedure SYNC_INVOICE******************/

drop procedure if exists sync_invoice;
delimiter //
CREATE PROCEDURE sync_invoice()
BEGIN

-- declare a local variable
	DECLARE v_invoiceno INT DEFAULT 0;
	DECLARE date_diff INT DEFAULT 0;
    DECLARE dateissued DATE;
    DECLARE v_status VARCHAR(20);
    DECLARE v_finito FLOAT DEFAULT 0;
    
    -- declare a cursor
    DECLARE c_invoice CURSOR FOR
    SELECT  INVOICENO,DATEISSUED,STATUS,DATEDIFF(now(),DATEISSUED)
	FROM invoice
    WHERE (DATEDIFF(now(),DATEISSUED) >30 AND STATUS = 'UNPAID');
    -- delare the handler
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finito = 1;
     
	-- OPEN THE CURSOR AND LOOP THROUGH THE ROWS
	OPEN c_invoice;      
	WHILE (v_finito=0) DO

			FETCH c_invoice INTO v_invoiceno,dateissued,v_status,date_diff;
            
            IF (v_finito=0) THEN
			    UPDATE invoice
                SET invoice.STATUS= 'OVERDUE'
                WHERE INVOICENO=v_invoiceno;
				
			END IF;
      
	END WHILE;
	CLOSE c_invoice;
END//

