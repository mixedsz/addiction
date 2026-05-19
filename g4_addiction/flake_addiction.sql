CREATE TABLE IF NOT EXISTS `flake_addiction` (
    `identifier`     VARCHAR(60)  NOT NULL,
    `drug`           VARCHAR(50)  NOT NULL,
    `remaining_time` INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`, `drug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
