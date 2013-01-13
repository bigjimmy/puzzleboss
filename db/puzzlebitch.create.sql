SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

DROP SCHEMA IF EXISTS `puzzlebitch-jrandall` ;
CREATE SCHEMA IF NOT EXISTS `puzzlebitch-jrandall` DEFAULT CHARACTER SET latin1 ;
USE `puzzlebitch-jrandall` ;

-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`round`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`round` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`round` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `name` VARCHAR(500) NOT NULL ,
  `round_uri` TEXT NULL ,
  `drive_uri` VARCHAR(300) NULL ,
  `drive_id` VARCHAR(100) NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `name_UNIQUE` (`name` ASC) ,
  UNIQUE INDEX `drive_uri_UNIQUE` (`drive_uri` ASC) ,
  UNIQUE INDEX `drive_id_UNIQUE` (`drive_id` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`puzzle`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `name` VARCHAR(500) NOT NULL ,
  `puzzle_uri` TEXT NULL ,
  `drive_uri` VARCHAR(300) NULL ,
  `pb_comments` TEXT NULL ,
  `status` ENUM('New','Being worked','Needs eyes','Solved') NOT NULL ,
  `answer` VARCHAR(500) NULL ,
  `round_id` INT NOT NULL ,
  `drive_id` VARCHAR(100) NULL ,
  `round_meta_p` TINYINT(1) NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_puzzles_rounds1_idx` (`round_id` ASC) ,
  UNIQUE INDEX `name_UNIQUE` (`name` ASC) ,
  UNIQUE INDEX `drive_id_UNIQUE` (`drive_id` ASC) ,
  UNIQUE INDEX `drive_uri_UNIQUE` (`drive_uri` ASC) ,
  CONSTRAINT `fk_puzzle_round1`
    FOREIGN KEY (`round_id` )
    REFERENCES `puzzlebitch-jrandall`.`round` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`solver`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `name` VARCHAR(500) NOT NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `uid_UNIQUE` (`name` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`location`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `name` VARCHAR(500) NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `name_UNIQUE` (`name` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`puzzle_solver`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_solver` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_solver` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `puzzle_id` INT NULL ,
  `solver_id` INT NOT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_puzzles_solvers_puzzles1_idx` (`puzzle_id` ASC) ,
  INDEX `fk_puzzles_solvers_solvers1_idx` (`solver_id` ASC) ,
  CONSTRAINT `fk_puzzle_solver_puzzle1`
    FOREIGN KEY (`puzzle_id` )
    REFERENCES `puzzlebitch-jrandall`.`puzzle` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_puzzle_solver_solver1`
    FOREIGN KEY (`solver_id` )
    REFERENCES `puzzlebitch-jrandall`.`solver` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`location_solver`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_solver` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_solver` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `solver_id` INT NOT NULL ,
  `location_id` INT NULL ,
  INDEX `fk_locations_solvers_solvers1_idx` (`solver_id` ASC) ,
  INDEX `fk_locations_solvers_locations1_idx` (`location_id` ASC) ,
  PRIMARY KEY (`id`) ,
  CONSTRAINT `fk_location_solver_solver1`
    FOREIGN KEY (`solver_id` )
    REFERENCES `puzzlebitch-jrandall`.`solver` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_location_solver_location1`
    FOREIGN KEY (`location_id` )
    REFERENCES `puzzlebitch-jrandall`.`location` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`answerattempt`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`answerattempt` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`answerattempt` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `answer` VARCHAR(500) NOT NULL ,
  `time` TIMESTAMP NOT NULL ,
  `puzzle_id` INT NOT NULL ,
  `status` ENUM('PENDING','WRONG','CORRECT') NOT NULL DEFAULT 'PENDING' ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_answerattempts_puzzles1_idx` (`puzzle_id` ASC) ,
  CONSTRAINT `fk_answerattempt_puzzle1`
    FOREIGN KEY (`puzzle_id` )
    REFERENCES `puzzlebitch-jrandall`.`puzzle` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`clientindex`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`clientindex` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`clientindex` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  PRIMARY KEY (`id`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`audit_puzzle`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`audit_puzzle` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`audit_puzzle` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `action` ENUM('INSERT','UPDATE','DELETE') NOT NULL ,
  `user` VARCHAR(500) NULL ,
  `puzzle_id` INT NOT NULL ,
  `old_name` VARCHAR(500) NULL ,
  `new_name` VARCHAR(500) NULL ,
  `old_puzzle_uri` TEXT NULL ,
  `new_puzzle_uri` TEXT NULL ,
  `old_answer` VARCHAR(500) NULL ,
  `new_answer` VARCHAR(500) NULL ,
  `old_pb_comments` TEXT NULL ,
  `new_pb_comments` TEXT NULL ,
  `old_drive_uri` VARCHAR(300) NULL ,
  `new_drive_uri` VARCHAR(300) NULL ,
  `old_drive_id` VARCHAR(100) NULL ,
  `new_drive_id` VARCHAR(100) NULL ,
  `old_round_meta_p` TINYINT(1) NULL ,
  `new_round_meta_p` TINYINT(1) NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `id_UNIQUE` (`id` ASC) ,
  INDEX `fk_audit_puzzle_puzzle1_idx` (`puzzle_id` ASC) ,
  CONSTRAINT `fk_audit_puzzle_puzzle1`
    FOREIGN KEY (`puzzle_id` )
    REFERENCES `puzzlebitch-jrandall`.`puzzle` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`log`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`log` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`log` (
  `version` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `user` VARCHAR(500) NULL ,
  `module` ENUM('puzzles','rounds','solvers','locations') NOT NULL ,
  `name` VARCHAR(500) NULL ,
  `part` ENUM('answer','answerattempts','comments','cursolvers','name','solvers','status','xyzloc','puzzles') NULL ,
  PRIMARY KEY (`version`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`puzzle_location`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_location` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_location` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `puzzle_id` INT NULL ,
  `location_id` INT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_puzzle_location_puzzle1_idx` (`puzzle_id` ASC) ,
  INDEX `fk_puzzle_location_location1_idx` (`location_id` ASC) ,
  CONSTRAINT `fk_puzzle_location_puzzle1`
    FOREIGN KEY (`puzzle_id` )
    REFERENCES `puzzlebitch-jrandall`.`puzzle` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_puzzle_location_location1`
    FOREIGN KEY (`location_id` )
    REFERENCES `puzzlebitch-jrandall`.`location` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`config`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`config` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`config` (
  `key` VARCHAR(100) NOT NULL ,
  `val` VARCHAR(100) NULL ,
  UNIQUE INDEX `key_UNIQUE` (`key` ASC) ,
  PRIMARY KEY (`key`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `puzzlebitch-jrandall`.`activity`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`activity` ;

CREATE  TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`activity` (
  `id` INT NOT NULL AUTO_INCREMENT ,
  `time` TIMESTAMP NOT NULL ,
  `solver_id` INT NOT NULL ,
  `puzzle_id` INT NULL ,
  `source` ENUM('google','pb_auto','pb_manual','bigjimmy','twiki','squid','apache','xmpp') NULL ,
  `type` ENUM('create','open','revise','comment','interact') NULL ,
  `uri` TEXT NULL ,
  `source_version` INT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_google_activity_solver1_idx` (`solver_id` ASC) ,
  INDEX `fk_google_activity_puzzle1_idx` (`puzzle_id` ASC) ,
  CONSTRAINT `fk_google_activity_solver1`
    FOREIGN KEY (`solver_id` )
    REFERENCES `puzzlebitch-jrandall`.`solver` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_google_activity_puzzle1`
    FOREIGN KEY (`puzzle_id` )
    REFERENCES `puzzlebitch-jrandall`.`puzzle` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

USE `puzzlebitch-jrandall` ;

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_view`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_view` (`id` INT, `name` INT, `status` INT, `answer` INT, `round` INT, `comments` INT, `gssuri` INT, `drive_id` INT, `round_meta_p` INT, `linkid` INT, `uri` INT, `solvers` INT, `locations` INT, `cursolvers` INT, `xyzloc` INT, `wrong_answers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_solvers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_solvers` (`puzzle_id` INT, `solvers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_locations`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_locations` (`puzzle_id` INT, `locations` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_cursolvers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_cursolvers` (`puzzle_id` INT, `cursolvers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_curlocations`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_curlocations` (`puzzle_id` INT, `curlocations` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_wrong_answers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answers` (`puzzle_id` INT, `wrong_answers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_solver_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_solver_distinct` (`puzzle_id` INT, `solver_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_location_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_location_distinct` (`puzzle_id` INT, `location_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_cursolver_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_cursolver_distinct` (`solver_id` INT, `puzzle_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_curlocation_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_curlocation_distinct` (`location_id` INT, `puzzle_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct` (`answer` INT, `puzzle_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_cursolver_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_cursolver_distinct` (`solver_id` INT, `location_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_solver_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_solver_distinct` (`location_id` INT, `solver_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_puzzle_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_puzzle_distinct` (`location_id` INT, `puzzle_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_curpuzzle_distinct`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_curpuzzle_distinct` (`puzzle_id` INT, `location_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_solvers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_solvers` (`location_id` INT, `solvers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_cursolvers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_cursolvers` (`location_id` INT, `cursolvers` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_puzzles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_puzzles` (`location_id` INT, `puzzles` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_curpuzzles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_curpuzzles` (`location_id` INT, `curpuzzles` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`location_view`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`location_view` (`id` INT, `name` INT, `solvers` INT, `puzzles` INT, `cursolvers` INT, `curpuzzles` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`solver_puzzles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver_puzzles` (`solver_id` INT, `puzzles` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`solver_locations`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver_locations` (`solver_id` INT, `locations` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`solver_view`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver_view` (`id` INT, `name` INT, `locations` INT, `puzzles` INT, `xyzloc` INT, `puzz` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`solver_curlocation`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver_curlocation` (`solver_id` INT, `curlocation` INT, `curlocation_id` INT);

-- -----------------------------------------------------
-- Placeholder table for view `puzzlebitch-jrandall`.`solver_curpuzzle`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `puzzlebitch-jrandall`.`solver_curpuzzle` (`solver_id` INT, `curpuzzle` INT, `curpuzzle_id` INT);

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_view`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_view` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_view`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_view` AS
SELECT 	`puzzle`.`id` AS `id`,
		`puzzle`.`name` AS `name`,
		`puzzle`.`status` AS `status`, 
		`puzzle`.`answer` AS `answer`, 
		`round`.`name` AS `round`, 
		`puzzle`.`pb_comments` AS `comments`, 
		`puzzle`.`drive_uri` AS `gssuri`, 
		`puzzle`.`drive_id` AS `drive_id`,
		`puzzle`.`round_meta_p` AS `round_meta_p`,
		CONCAT('<a href="',`puzzle`.`puzzle_uri`,'" target="',`puzzle`.`name`,'">',`puzzle`.`name`,'</a>') AS `linkid`, 
		`puzzle`.`puzzle_uri` AS `uri`,
		`ps`.`solvers`,
		`pl`.`locations`,
		`cps`.`cursolvers`,
		`cpl`.`curlocations` AS `xyzloc`,
		`aa`.`wrong_answers`
FROM `puzzle` 
JOIN `round` ON `round`.`id`=`puzzle`.`round_id` 
LEFT JOIN `puzzle_solvers` AS `ps` ON `ps`.`puzzle_id`=`puzzle`.`id`
LEFT JOIN `puzzle_locations` AS `pl` ON `pl`.`puzzle_id`=`puzzle`.`id`
LEFT JOIN `puzzle_cursolvers` AS `cps` ON `cps`.`puzzle_id`=`puzzle`.`id`
LEFT JOIN `puzzle_curlocations` AS `cpl` ON `cpl`.`puzzle_id`=`puzzle`.`id`
LEFT JOIN `puzzle_wrong_answers` AS `aa` ON `aa`.`puzzle_id`=`puzzle`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_solvers`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_solvers` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_solvers`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_solvers` AS
SELECT `puzzle`.`id` as `puzzle_id`, 
		GROUP_CONCAT(`solver`.`name`) AS `solvers`
		FROM `puzzle` 
		LEFT JOIN `puzzle_solver_distinct` AS `ps` ON `ps`.`puzzle_id`=`puzzle`.`id` 
		LEFT JOIN `solver` ON `solver`.`id`=`ps`.`solver_id`
		GROUP BY `puzzle`.`id`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_locations`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_locations` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_locations`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_locations` AS
SELECT `puzzle`.`id` as `puzzle_id`, 
			GROUP_CONCAT(`location`.`name`) AS `locations`
			FROM `puzzle` 
			LEFT JOIN `puzzle_location_distinct` AS `pl` ON `pl`.`puzzle_id`=`puzzle`.`id` 
			LEFT JOIN `location` ON `location`.`id`=`pl`.`location_id`
			GROUP BY `puzzle`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_cursolvers`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_cursolvers` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_cursolvers`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_cursolvers` AS
SELECT `puzzle`.`id` as `puzzle_id`, 
			GROUP_CONCAT(`solver`.`name`) AS `cursolvers`
			FROM `puzzle` 
			LEFT JOIN `puzzle_cursolver_distinct` AS `ps` ON `ps`.`puzzle_id`=`puzzle`.`id` 
			LEFT JOIN `solver` ON `solver`.`id`=`ps`.`solver_id`
			GROUP BY `puzzle`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_curlocations`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_curlocations` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_curlocations`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_curlocations` AS
SELECT `puzzle`.`id` as `puzzle_id`, 
			GROUP_CONCAT(`location`.`name`) AS `curlocations`
			FROM `puzzle` 
			LEFT JOIN `puzzle_curlocation_distinct` AS `pl` ON `pl`.`puzzle_id`=`puzzle`.`id`
			LEFT JOIN `location` ON `location`.`id`=`pl`.`location_id`
			GROUP BY `puzzle`.`id`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_wrong_answers`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answers` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answers`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_wrong_answers` AS
SELECT `puzzle`.`id` as `puzzle_id`, 
			GROUP_CONCAT(`aa`.`answer`) AS `wrong_answers` 
			FROM `puzzle` 
			LEFT JOIN `puzzle_wrong_answer_distinct` AS `aa` ON `aa`.`puzzle_id`=`puzzle`.`id` 
			GROUP BY `puzzle`.`id`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_solver_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_solver_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_solver_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_solver_distinct` AS
SELECT DISTINCT `puzzle_id`, `solver_id` FROM `puzzle_solver`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_location_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_location_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_location_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_location_distinct` AS
SELECT DISTINCT `puzzle_id`, `location_id` FROM `puzzle_location`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_cursolver_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_cursolver_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_cursolver_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_cursolver_distinct` AS
SELECT DISTINCT `solver`.`id` AS `solver_id`, `ps`.`puzzle_id` AS `puzzle_id` FROM `solver` 
LEFT JOIN `puzzle_solver` AS `ps` ON `ps`.`solver_id`=`solver`.`id` 
AND `ps`.`puzzle_id` = (SELECT `subps`.`puzzle_id` FROM `puzzle_solver` AS `subps` WHERE `subps`.`solver_id`=`ps`.`solver_id` ORDER BY `subps`.`id` DESC LIMIT 1)
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_curlocation_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_curlocation_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_curlocation_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_curlocation_distinct` AS
SELECT DISTINCT `location`.`id` AS `location_id`, `pl`.`puzzle_id` AS `puzzle_id` FROM `location` 
LEFT JOIN `puzzle_location` AS `pl` ON `pl`.`location_id`=`location`.`id` 
AND `pl`.`puzzle_id` = (SELECT `subpl`.`puzzle_id` FROM `puzzle_location` AS `subpl` WHERE `subpl`.`location_id`=`pl`.`location_id` ORDER BY `subpl`.`id` DESC LIMIT 1)
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`puzzle_wrong_answer_distinct` AS
SELECT DISTINCT `answer`,`puzzle_id` FROM `answerattempt` WHERE `answerattempt`.`status`='WRONG';

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_cursolver_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_cursolver_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_cursolver_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_cursolver_distinct` AS
SELECT DISTINCT `solver`.`id` AS `solver_id`, `ls`.`location_id` AS `location_id` FROM `solver` 
LEFT JOIN `location_solver` AS `ls` ON `ls`.`solver_id`=`solver`.`id` 
AND `ls`.`location_id` = (SELECT `subls`.`location_id` FROM `location_solver` AS `subls` WHERE `subls`.`solver_id`=`ls`.`solver_id` ORDER BY `subls`.`id` DESC LIMIT 1)
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_solver_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_solver_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_solver_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_solver_distinct` AS
SELECT DISTINCT `location_id`, `solver_id` FROM `location_solver`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_puzzle_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_puzzle_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_puzzle_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_puzzle_distinct` AS
SELECT DISTINCT `location_id`, `puzzle_id` FROM `puzzle_location`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_curpuzzle_distinct`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_curpuzzle_distinct` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_curpuzzle_distinct`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_curpuzzle_distinct` AS
SELECT DISTINCT `puzzle`.`id` AS `puzzle_id`, `pl`.`location_id` AS `location_id` FROM `puzzle` 
LEFT JOIN `puzzle_location` AS `pl` ON `pl`.`puzzle_id`=`puzzle`.`id` 
AND `pl`.`location_id` = (SELECT `subpl`.`location_id` FROM `puzzle_location` AS `subpl` WHERE `subpl`.`puzzle_id`=`pl`.`puzzle_id` ORDER BY `subpl`.`id` DESC LIMIT 1)
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_solvers`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_solvers` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_solvers`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_solvers` AS
SELECT `location`.`id` as `location_id`, 
		GROUP_CONCAT(`solver`.`name`) AS `solvers`
		FROM `location` 
		LEFT JOIN `location_solver_distinct` AS `ls` ON `ls`.`location_id`=`location`.`id` 
		LEFT JOIN `solver` ON `solver`.`id`=`ls`.`solver_id`
		GROUP BY `location`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_cursolvers`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_cursolvers` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_cursolvers`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_cursolvers` AS
SELECT `location`.`id` as `location_id`, 
			GROUP_CONCAT(`solver`.`name`) AS `cursolvers`
			FROM `location` 
			LEFT JOIN `location_cursolver_distinct` AS `ls` ON `ls`.`location_id`=`location`.`id` 
			LEFT JOIN `solver` ON `solver`.`id`=`ls`.`solver_id`
			GROUP BY `location`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_puzzles`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_puzzles` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_puzzles`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_puzzles` AS
SELECT `location`.`id` as `location_id`, 
		GROUP_CONCAT(`puzzle`.`name`) AS `puzzles`
		FROM `location` 
		LEFT JOIN `location_puzzle_distinct` AS `lp` ON `lp`.`location_id`=`location`.`id` 
		LEFT JOIN `puzzle` ON `puzzle`.`id`=`lp`.`puzzle_id`
		GROUP BY `location`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_curpuzzles`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_curpuzzles` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_curpuzzles`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_curpuzzles` AS
SELECT `location`.`id` as `location_id`, 
			GROUP_CONCAT(`puzzle`.`name`) AS `curpuzzles`
			FROM `location` 
			LEFT JOIN `location_curpuzzle_distinct` AS `lp` ON `lp`.`location_id`=`location`.`id` 
			LEFT JOIN `puzzle` ON `puzzle`.`id`=`lp`.`puzzle_id`
			GROUP BY `location`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`location_view`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`location_view` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`location_view`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`location_view` AS
SELECT 	
		`location`.`id` AS `id`,
		`location`.`name` AS `name`,
		`ps`.`solvers`,
		`pl`.`puzzles`,
		`cps`.`cursolvers`,
		`cpl`.`curpuzzles`
FROM `location` 
LEFT JOIN `location_solvers` AS `ps` ON `ps`.`location_id`=`location`.`id`
LEFT JOIN `location_puzzles` AS `pl` ON `pl`.`location_id`=`location`.`id`
LEFT JOIN `location_cursolvers` AS `cps` ON `cps`.`location_id`=`location`.`id`
LEFT JOIN `location_curpuzzles` AS `cpl` ON `cpl`.`location_id`=`location`.`id`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`solver_puzzles`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`solver_puzzles` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver_puzzles`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`solver_puzzles` AS
SELECT `solver`.`id` as `solver_id`, 
		GROUP_CONCAT(`puzzle`.`name`) AS `puzzles`
		FROM `solver` 
		LEFT JOIN `puzzle_solver_distinct` AS `ps` ON `ps`.`solver_id`=`solver`.`id` 
		LEFT JOIN `puzzle` ON `puzzle`.`id`=`ps`.`puzzle_id`
		GROUP BY `solver`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`solver_locations`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`solver_locations` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver_locations`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`solver_locations` AS
SELECT `solver`.`id` as `solver_id`, 
		GROUP_CONCAT(`location`.`name`) AS `locations`
		FROM `solver` 
		LEFT JOIN `location_solver_distinct` AS `ls` ON `ls`.`solver_id`=`solver`.`id` 
		LEFT JOIN `location` ON `location`.`id`=`ls`.`location_id`
		GROUP BY `solver`.`id`;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`solver_view`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`solver_view` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver_view`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`solver_view` AS
SELECT 		
	`solver`.`id` AS `id`,
	`solver`.`name` AS `name`,
	`sl`.`locations`,
	`sp`.`puzzles`,
	`csl`.`curlocation` AS `xyzloc`,
	`csp`.`curpuzzle` AS `puzz`
FROM `solver` 
LEFT JOIN `solver_locations` AS `sl` ON `sl`.`solver_id`=`solver`.`id`
LEFT JOIN `solver_puzzles` AS `sp` ON `sp`.`solver_id`=`solver`.`id`
LEFT JOIN `solver_curlocation` AS `csl` ON `csl`.`solver_id`=`solver`.`id`
LEFT JOIN `solver_curpuzzle` AS `csp` ON `csp`.`solver_id`=`solver`.`id`
;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`solver_curlocation`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`solver_curlocation` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver_curlocation`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`solver_curlocation` AS
SELECT `solver`.`id` as `solver_id`, 
			`location`.`name` AS `curlocation`,
			`location`.`id` AS `curlocation_id`
			FROM `solver` 
			LEFT JOIN `location_cursolver_distinct` AS `ls` ON `ls`.`solver_id`=`solver`.`id` 
			LEFT JOIN `location` ON `location`.`id`=`ls`.`location_id`
			;

-- -----------------------------------------------------
-- View `puzzlebitch-jrandall`.`solver_curpuzzle`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `puzzlebitch-jrandall`.`solver_curpuzzle` ;
DROP TABLE IF EXISTS `puzzlebitch-jrandall`.`solver_curpuzzle`;
USE `puzzlebitch-jrandall`;
CREATE  OR REPLACE VIEW `puzzlebitch-jrandall`.`solver_curpuzzle` AS
SELECT `solver`.`id` as `solver_id`, 
			`puzzle`.`name` AS `curpuzzle`,
			`puzzle`.`id` AS `curpuzzle_id`
			FROM `solver` 
			LEFT JOIN `puzzle_cursolver_distinct` AS `sp` ON `sp`.`solver_id`=`solver`.`id` 
			LEFT JOIN `puzzle` ON `puzzle`.`id`=`sp`.`puzzle_id`
;
USE `puzzlebitch-jrandall`;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_ADEL` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_ADEL` AFTER DELETE ON puzzle FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
INSERT INTO `log` (`user`,`module`) VALUES (@user,'puzzles');
INSERT INTO `audit_puzzle` 
	(
		`action`,
		`user`,
		`puzzle_id`,
		`old_name`,
		`old_puzzle_uri`,
		`old_drive_uri`,
		`old_pb_comments`,
		`old_answer`,
		`old_drive_id`,
		`old_round_meta_p`
	) 
	VALUES 
	(
		'DELETE',
		@user,
		OLD.id, 
		OLD.name,
		OLD.puzzle_uri,
		OLD.drive_uri,
		OLD.pb_comments,
		OLD.answer,
		OLD.drive_id,
		OLD.round_meta_p
	);
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_AINS` AFTER INSERT ON puzzle FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'puzzles',NEW.name);
INSERT INTO `audit_puzzle` 
	(
		`action`,
		`user`,
		`puzzle_id`,
		`new_name`,
		`new_puzzle_uri`,
		`new_drive_uri`,
		`new_pb_comments`,
		`new_answer`,
		`new_drive_id`,
		`new_round_meta_p`
	)
	VALUES
	(
		'INSERT',
		@user,
		NEW.id, 
		NEW.name,
		NEW.puzzle_uri,
		NEW.drive_uri,
		NEW.pb_comments,
		NEW.answer,
		NEW.drive_id,
		NEW.round_meta_p
	);
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_AUPD` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_AUPD` AFTER UPDATE ON puzzle FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
IF IFNULL(OLD.name,'') <> IFNULL(NEW.name,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'name');
END IF;
IF IFNULL(OLD.puzzle_uri,'') <> IFNULL(NEW.puzzle_uri,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'puzzle_uri');
END IF;
IF IFNULL(OLD.drive_uri,'') <> IFNULL(NEW.drive_uri,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'drive_uri');
END IF;
IF IFNULL(OLD.pb_comments,'') <> IFNULL(NEW.pb_comments,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'comments');
END IF;
IF IFNULL(OLD.answer,'') <> IFNULL(NEW.answer,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'answer');
END IF;
IF IFNULL(OLD.status,'') <> IFNULL(NEW.status,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'puzzles',NEW.name,'status');
END IF;
INSERT INTO `audit_puzzle` 
	(
		`action`,
		`user`,
		`puzzle_id`,
		`old_name`,
		`new_name`,
		`old_puzzle_uri`,
		`new_puzzle_uri`,
		`old_drive_uri`,
		`new_drive_uri`,
		`old_pb_comments`,
		`new_pb_comments`,
		`old_answer`,
		`new_answer`,
		`old_drive_id`,
		`new_drive_id`,
		`old_round_meta_p`,
		`new_round_meta_p`
	)
	VALUES
	(
		'UPDATE',
		@user,
		OLD.id, 
		OLD.name,
		NEW.name,
		OLD.puzzle_uri,
		NEW.puzzle_uri,
		OLD.drive_uri,
		NEW.drive_uri,
		OLD.pb_comments,
		NEW.pb_comments,
		OLD.answer,
		NEW.answer,
		OLD.drive_id,
		NEW.drive_id,
		OLD.round_meta_p,
		NEW.round_meta_p
	);
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`round_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `round_AINS` AFTER INSERT ON round FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one

BEGIN
INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'rounds',NEW.name);
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`round_AUPD` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `round_AUPD` AFTER UPDATE ON round FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
IF IFNULL(OLD.name,'') <> IFNULL(NEW.name,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'rounds',NEW.name,'name');
END IF;
IF IFNULL(OLD.round_uri,'') <> IFNULL(NEW.round_uri,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'rounds',NEW.name,'round_uri');
END IF;
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`round_ADEL` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `round_ADEL` AFTER DELETE ON round FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'rounds',OLD.name);
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`solver_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `solver_AINS` AFTER INSERT ON solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'solvers',NEW.name);
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`solver_AUPD` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `solver_AUPD` AFTER UPDATE ON solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
IF IFNULL(OLD.name,'') <> IFNULL(NEW.name,'') THEN 
	INSERT INTO `log` (`user`,`module`,`name`,`part`) VALUES (@user,'solvers',NEW.name,'name');
END IF;
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`solver_ADEL` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `solver_ADEL` AFTER DELETE ON solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'solvers',OLD.name);
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`location_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `location_AINS` AFTER INSERT ON location FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'locations',NEW.name);
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`location_ADEL` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `location_ADEL` AFTER DELETE ON location FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one

BEGIN
	INSERT INTO `log` (`user`,`module`,`name`) VALUES (@user,'locations',OLD.name);
END$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`location_AUPD` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `location_AUPD` AFTER UPDATE ON location FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
IF IFNULL(OLD.name,'') <> IFNULL(NEW.name,'') THEN 
	INSERT 	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'locations',NEW.name,'name');
END IF;
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_solver_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_solver_AINS` AFTER INSERT ON puzzle_solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @puzzname = (SELECT `name` FROM `puzzle` WHERE `puzzle`.`id`=NEW.puzzle_id);
	Set @solvername = (SELECT `name` FROM `solver` WHERE `solver`.`id`=NEW.solver_id);
    Set @loc_id = (SELECT `curlocation_id` FROM `solver_curlocation` WHERE `solver_id`=NEW.solver_id LIMIT 1);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'puzzles',@puzzname,'cursolvers');
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'solvers',@solvername,'puzzles');
	IF NOT (ISNULL(@loc_id) AND ISNULL(NEW.puzzle_id)) THEN
		INSERT INTO `puzzle_location` (`puzzle_id`,`location_id`) VALUES (NEW.puzzle_id, @loc_id);
	END IF;
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_solver_BINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_solver_BINS` BEFORE INSERT ON puzzle_solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @puzzname = (SELECT `name` FROM `puzzle` WHERE `puzzle`.`id`=NEW.puzzle_id);
	Set @oldpuzzname = (SELECT `curpuzzle` FROM `solver_curpuzzle` WHERE `solver_id`=NEW.solver_id);
	Set @solvername = (SELECT `name` FROM `solver` WHERE `solver`.`id`=NEW.solver_id);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'puzzles',@oldpuzzname,'cursolvers');
	IF ((SELECT COUNT(*) FROM `puzzle_solver` WHERE `puzzle_id`=NEW.puzzle_id AND `solver_id`=NEW.solver_id)=0) THEN
		INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
				VALUES (@user,'puzzles',@puzzname,'solvers');
	END IF;
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`location_solver_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `location_solver_AINS` AFTER INSERT ON location_solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @locname = (SELECT name FROM `location` WHERE `location`.`id`=NEW.location_id);
	Set @solvername = (SELECT name FROM `solver` WHERE `solver`.`id`=NEW.solver_id);
    Set @puzz_id = (SELECT `curpuzzle_id` FROM `solver_curpuzzle` WHERE `solver_id`=NEW.solver_id  LIMIT 1);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'locations',@locname,'cursolvers');
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'solvers',@solvername,'xyzloc');
	IF NOT (ISNULL(@puzz_id) AND ISNULL(NEW.location_id)) THEN
		INSERT INTO `puzzle_location` (`puzzle_id`,`location_id`) VALUES (@puzz_id, NEW.location_id);
	END IF;
END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`location_solver_BINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `location_solver_BINS` BEFORE INSERT ON location_solver FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @locname = (SELECT name FROM `location` WHERE `location`.`id`=NEW.location_id);
	Set @oldlocname = (SELECT `curlocation` FROM `solver_curlocation` WHERE `solver_id`=NEW.solver_id);
	Set @solvername = (SELECT name FROM `solver` WHERE `solver`.`id`=NEW.solver_id);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'locations',@oldlocname,'cursolvers');
	IF ((SELECT COUNT(*) FROM `location_solver` WHERE `location_id`=NEW.location_id AND `solver_id`=NEW.solver_id)=0) THEN
		INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
				VALUES (@user,'puzzles',@puzzname,'solvers');
	END IF;
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`answerattempt_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `answerattempt_AINS` AFTER INSERT ON answerattempt FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @puzzname = (SELECT name FROM `puzzle` WHERE `puzzle`.`id`=NEW.puzzle_id);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'puzzles',@puzzname,'answerattempts');
END
$$


DELIMITER ;

DELIMITER $$

USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_location_AINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_location_AINS` AFTER INSERT ON puzzle_location FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @puzzname = (SELECT name FROM `puzzle` WHERE `puzzle`.`id`=NEW.puzzle_id);
	Set @locname = (SELECT name FROM `location` WHERE `location`.`id`=NEW.location_id);
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'puzzles',@puzzname,'xyzloc');
	INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
			VALUES (@user,'locations',@locname,'puzzles');

END
$$


USE `puzzlebitch-jrandall`$$
DROP TRIGGER IF EXISTS `puzzlebitch-jrandall`.`puzzle_location_BINS` $$
USE `puzzlebitch-jrandall`$$


CREATE TRIGGER `puzzle_location_BINS` BEFORE INSERT ON puzzle_location FOR EACH ROW
-- Edit trigger body code below this line. Do not edit lines above this one
BEGIN
	Set @puzzname = (SELECT `name` FROM `puzzle` WHERE `puzzle`.`id`=NEW.puzzle_id);
	Set @oldpuzzname = (SELECT `name` FROM `puzzle` JOIN `location_curpuzzle_distinct` AS `lcd` ON `lcd`.`puzzle_id`=`puzzle`.`id` AND `lcd`.`location_id`=NEW.location_id WHERE `puzzle`.`id`=NEW.puzzle_id);
	Set @locname = (SELECT name FROM `location` WHERE `location`.`id`=NEW.location_id);
	IF ((SELECT COUNT(*) FROM `puzzle_location` WHERE `puzzle_id`=NEW.puzzle_id AND `location_id`=NEW.location_id)=0) THEN
		INSERT	INTO `log` (`user`,`module`,`name`,`part`) 
				VALUES (@user,'puzzles',@puzzname,'xyzloc');
	END IF;
END
$$


DELIMITER ;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
