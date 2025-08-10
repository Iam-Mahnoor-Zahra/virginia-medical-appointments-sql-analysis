use sql_project;


select * from virginia_patient_appointments;

set sql_safe_updates = 0;

-- UPDATING DATE FORMAT OF SCHEDULEDDAY COLUMN
UPDATE virginia_patient_appointments
SET ScheduledDay = STR_TO_DATE(ScheduledDay, "%m/%d/%Y");

-- UPDATING DATE FORMAT OF APPOINTMENTDAY COLUMN
UPDATE virginia_patient_appointments
SET AppointmentDay = STR_TO_DATE(AppointmentDay, "%m/%d/%Y");

-- -----------------------------------------------------
-- -----------Basic SQL & Data Retrieval --------------
-- -----------------------------------------------------

-- 1. Retrieve all columns from the Appointments table.

select * from virginia_patient_appointments;

-- 2. List the first 10 appointments where the patient is older than 60. 

select * 
from virginia_patient_appointments
where Age > 60 ;

-- 3. Show the unique neighborhoods from which patients came.

select distinct Neighbourhood
from virginia_patient_appointments;

-- 4. Find all female patients who received an SMS reminder. Give count of them 

select Gender , count(Gender) as female_sms_count
from virginia_patient_appointments
where gender = 'Female' and SMS_received = 1 ;


-- 5. Display all appointments scheduled on or after '2023-05-01' and before '2023-06-01'. 

select *
from virginia_patient_appointments
where ScheduledDay >= '2023-05-01' and ScheduledDay < '2023-06-01' ;

-- ------------------------------------------|
-- ------Data Modification & Filtering-------|
-- ------------------------------------------|

-- 6.	Update the 'Showed_up' status to 'Yes' where it is null or empty
start transaction;

update virginia_patient_appointments
set Showed_up = 'Yes'
where Showed_up is null or trim(Showed_up) = '';


rollback;
commit;

/* 7.	Add a new column AppointmentStatus using a CASE statement:

○	'No Show' if Showed_up = 'No'

○	'Attended' otherwise    */
          
          
alter table virginia_patient_appointments
add column AppointmentStatus varchar(20);

update virginia_patient_appointments
set AppointmentStatus = case when Showed_up = 'No' then 'No Show'
                        else 'Attended'
                        end ;
                        
-- 8.	Filter appointments for diabetic patients with hypertension.
select *
from virginia_patient_appointments
where Diabetes = 1 and Hypertension = 1;

-- 9.	Order the records by Age in descending order and show only the top 5 oldest patients.
select *
from virginia_patient_appointments
order by age desc
limit 5;

-- 10.	Limit results to the first 5 appointments for patients under age 18.

select *
from virginia_patient_appointments
where age < 18
order by AppointmentDay 
limit 5;

-- ----------------------------------------
-- -------Aggregation & Grouping-----------
-- ----------------------------------------



-- 11.	Find the average age of patients for each gender.

select Gender , avg(Age) as Avg_Age
from virginia_patient_appointments
group by Gender;

-- 12.	Count how many patients received SMS reminders, grouped by Showed_up status.

select Showed_up , sum(SMS_received) as Total_SMS_received
from virginia_patient_appointments
group by Showed_up;

-- 13.	Count no-show appointments in each neighborhood using GROUP BY.

select Neighbourhood , count(*) as No_Show_Count
from virginia_patient_appointments
where AppointmentStatus = 'No Show'
group by Neighbourhood;

-- 14.	Show neighborhoods with more than 100 total appointments (HAVING clause).

select Neighbourhood , count(*) as appointment_count
from virginia_patient_appointments
group by Neighbourhood
having appointment_count > 100;

/* 15.	Use CASE to calculate the total number of:

○	children (Age < 12)

○	adults (Age BETWEEN 12 AND 60)

○	seniors (Age > 60)

*/

select PatientId, AppointmentID, Gender, Age ,
           case when Age < 12 then 'children'
				when Age between 12 and 60 then 'adults'
                when Age > 60 then 'seniors'
                end as Age_Status
from virginia_patient_appointments;


-- -----------------------------------------
-- -----------Window Functions--------------
-- -----------------------------------------


/* 16.	  Tracks how appointments accumulate over time in each neighbourhood. 
(Running Total of Appointments per Day)  In simple words:
How many appointments were there each day and how do the total appointments keep adding up over time in each neighborhood?  */

select Neighbourhood, AppointmentDay, 
        sum(count(AppointmentDay)) over(partition by Neighbourhood order by AppointmentDay) as Running_total_of_app
        from virginia_patient_appointments
        group by Neighbourhood ,AppointmentDay
        order by Neighbourhood, AppointmentDay
        ;

-- 17.	Use Dense_Rank() to rank patients by age within each gender group.

select *,
       dense_rank() over(partition by gender order by age desc) as Rank_by_age
       from virginia_patient_appointments ;
       
-- 18.	How many days have passed since the last appointment in the same neighborhood? (Hint: DATEDIFF and Lag) 
-- (This helps to see how frequently appointments are happening in each neighborhood.)

WITH Appointment_Gaps AS (
  SELECT 
    Neighbourhood,
    AppointmentDay,
    LAG(AppointmentDay) OVER (
      PARTITION BY Neighbourhood 
      ORDER BY AppointmentDay
    ) AS Previous_AppointmentDay
  FROM virginia_patient_appointments
)

SELECT 
  Neighbourhood,
  AppointmenStDay,
  Previous_AppointmentDay,
  DATEDIFF(AppointmentDay, Previous_AppointmentDay) AS Days_Since_Last_Appointment
FROM Appointment_Gaps
ORDER BY Neighbourhood, AppointmentDay;


-- 19.	Which neighborhoods have the highest number of missed appointments? 
-- Use DENSE_RANK() to rank neighborhoods based on the number of no-show appointments.


select Neighbourhood,count(AppointmentStatus),
       dense_rank() over( order by count(AppointmentStatus)) as missed_appointments
       from virginia_patient_appointments
       where AppointmentStatus = 'No Show' 
       group by Neighbourhood
       ORDER BY missed_appointments;
       
/* 20.	 Are patients more likely to miss appointments on certain days of the week?
 Steps to follow for question # 20
•	(Use the AppointmentDay column in function dayname() to extract the day name (like Monday, Tuesday, etc.).
•	Count how many appointments were scheduled, how many showed up (showed_up = "yes") and how many were missed (Showed_up = 'No') on each day.
•	Calculate the percentage of shows and no-shows for better comparison between days. 
•	Formula: (count of Showed_up = 'yes' / total appointment count ) * 100, Use round function to  show upto two decimal points
•	Sort the result by No_Show_Percent in descending order to see the worst-performing days first.

       
      */
      
      select
    DAYNAME(AppointmentDay) as DayName,
    count(*) as Total_Appointments,
    sum(case when Showed_up = 'Yes' then 1 else 0 end) as Shows,
    sum(case when Showed_up = 'No' then 1 else 0 end) as No_Shows,
    round(sum(case when Showed_up = 'Yes' then 1 else 0 end) * 100.0 / COUNT(*), 2) as Show_Percent,
    round(sum(case when Showed_up = 'No' then 1 else 0 end) * 100.0 / COUNT(*), 2) as No_Show_Percent
from virginia_patient_appointments
group by DAYNAME(AppointmentDay)
order by No_Show_Percent desc;


