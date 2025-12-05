DELIMITER $$

DROP PROCEDURE IF EXISTS `uspGetAllPatientReferrals`$$

CREATE DEFINER=`austria_admin`@`%` PROCEDURE `uspGetAllPatientReferrals`(
    IN p_SearchTerm VARCHAR(255),
    IN p_PageNumber INT,
    IN p_PageSize INT,
    IN p_SortCol VARCHAR(100),
    IN p_SortDir VARCHAR(100))
BEGIN
    DECLARE v_Offset INT DEFAULT 0;
    DECLARE v_SearchTerm VARCHAR(255);
    DECLARE v_SortColSafe VARCHAR(100);
    DECLARE v_SortDirSafe VARCHAR(100);
    DECLARE v_TotalCount INT DEFAULT 0;
    DECLARE v_sql TEXT;
    DECLARE v_PageNumber INT DEFAULT 1;
    DECLARE v_PageSize INT DEFAULT 100;
    -- Process SearchTerm: if null/empty/blank, don't apply search filter
    SET v_SearchTerm = TRIM(IFNULL(p_SearchTerm, ''));
    
    -- Process pagination: use provided values or defaults
    -- If PageNumber is 0 or NULL, default to 1
    -- If PageSize is 0 or NULL, default to 100 (or use a large number to return all)
    IF p_PageNumber IS NULL OR p_PageNumber = 0 THEN
        SET v_PageNumber = 1;
    ELSE
        SET v_PageNumber = p_PageNumber;
    END IF;
    
    IF p_PageSize IS NULL OR p_PageSize = 0 THEN
        SET v_PageSize = 100;
    ELSE
        SET v_PageSize = p_PageSize;
    END IF;

    -- Process sorting: use provided values or defaults
    IF TRIM(IFNULL(p_SortCol, '')) = 'Id' THEN
        SET v_SortColSafe = 'pr.Id';
    ELSEIF TRIM(IFNULL(p_SortCol, '')) = 'FullName' THEN
        SET v_SortColSafe = 'CONCAT(pr.FirstName, " ", pr.LastName)';
    ELSEIF TRIM(IFNULL(p_SortCol, '')) = 'DateOfBirth' THEN
        SET v_SortColSafe = 'pr.DateOfBirth';
    ELSEIF TRIM(IFNULL(p_SortCol, '')) = 'HealthInsurance' THEN
        SET v_SortColSafe = 'pr.HealthInsurance';
    ELSEIF TRIM(IFNULL(p_SortCol, '')) = 'SocialSecurityNumber' THEN
        SET v_SortColSafe = 'pr.SocialSecurityNumber';
    ELSEIF TRIM(IFNULL(p_SortCol, '')) = 'CreatedDate' THEN
        SET v_SortColSafe = 'pr.CreatedDate';
    ELSE
        SET v_SortColSafe = 'pr.CreatedDate';
    END IF;

    -- Validate direction: default to DESC
    SET v_SortDirSafe = IF(UPPER(TRIM(IFNULL(p_SortDir, ''))) = 'ASC', 'ASC', 'DESC');

    -- Calculate offset for pagination
    SET v_Offset = (v_PageNumber - 1) * v_PageSize;

    -- Get total count and return as first result set
    -- Apply search filter only if SearchTerm is provided (not null/empty/blank)
    IF v_SearchTerm = '' THEN
        -- No search filter: return count of all records
        SELECT COUNT(*) AS TotalCount
        FROM PatientReferral;
    ELSE
        -- Apply search filter
        SELECT COUNT(*) AS TotalCount
        FROM PatientReferral
        WHERE (
            CONCAT(COALESCE(FirstName, ''), ' ', COALESCE(LastName, '')) COLLATE utf8mb4_unicode_ci LIKE CONCAT('%', v_SearchTerm, '%') COLLATE utf8mb4_unicode_ci
            OR COALESCE(HealthInsurance, '') COLLATE utf8mb4_unicode_ci LIKE CONCAT('%', v_SearchTerm, '%') COLLATE utf8mb4_unicode_ci
            OR COALESCE(SocialSecurityNumber, '') COLLATE utf8mb4_unicode_ci LIKE CONCAT('%', v_SearchTerm, '%') COLLATE utf8mb4_unicode_ci
        );
    END IF;

    -- Get paginated results
    -- Apply search filter only if SearchTerm is provided (not null/empty/blank)
    IF v_SearchTerm = '' THEN
        -- No search filter: return all records with pagination and sorting
        SET v_sql = CONCAT(
            'SELECT pr.Id, pr.FirstName, pr.LastName, pr.DateOfBirth, pr.HealthInsurance, pr.SocialSecurityNumber, ',
            'NULL AS DateOfDischarge, ''Active'' AS Status, pr.Attachments AS AttachmentsJson, pr.CreatedDate ',
            'FROM PatientReferral pr ',
            'ORDER BY ', v_SortColSafe, ' ', v_SortDirSafe, ' ',
            'LIMIT ', CAST(v_PageSize AS CHAR), ' OFFSET ', CAST(v_Offset AS CHAR)
        );
    ELSE
        -- Apply search filter - escape single quotes in search term
        SET v_SearchTerm = REPLACE(v_SearchTerm, '''', '''''');
        
        -- Apply search filter
        SET v_sql = CONCAT(
            'SELECT pr.Id, pr.FirstName, pr.LastName, pr.DateOfBirth, pr.HealthInsurance, pr.SocialSecurityNumber, ',
            'NULL AS DateOfDischarge, ''Active'' AS Status, pr.Attachments AS AttachmentsJson, pr.CreatedDate ',
            'FROM PatientReferral pr ',
            'WHERE (',
                'CONCAT(COALESCE(pr.FirstName, ""), " ", COALESCE(pr.LastName, "")) COLLATE utf8mb4_unicode_ci LIKE CONCAT("%", ''', v_SearchTerm, ''', "%") COLLATE utf8mb4_unicode_ci OR ',
                'COALESCE(pr.HealthInsurance, "") COLLATE utf8mb4_unicode_ci LIKE CONCAT("%", ''', v_SearchTerm, ''', "%") COLLATE utf8mb4_unicode_ci OR ',
                'COALESCE(pr.SocialSecurityNumber, "") COLLATE utf8mb4_unicode_ci LIKE CONCAT("%", ''', v_SearchTerm, ''', "%") COLLATE utf8mb4_unicode_ci',
            ') ',
            'ORDER BY ', v_SortColSafe, ' ', v_SortDirSafe, ' ',
            'LIMIT ', CAST(v_PageSize AS CHAR), ' OFFSET ', CAST(v_Offset AS CHAR)
        );
    END IF;

    -- Prepare and execute
    SET @v_sql = v_sql;
    PREPARE stmt FROM @v_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;