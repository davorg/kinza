CREATE TABLE year (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
name VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE form (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
name varchar(255),
year_id INTEGER NOT NULL,
FOREIGN KEY (year_id) REFERENCES year(id)
) ENGINE=InnoDB;

CREATE TABLE course (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
title VARCHAR(255) NOT NULL,
description TEXT,
teacher VARCHAR(255) NOT NULL DEFAULT "Mrs. Teacher",
room VARCHAR(255) NOT NULL DEFAULT "Room 101",
capacity INTEGER NOT NULL DEFAULT 27,
number_of_terms INTEGER NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE allowed_course_year (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
course_id INTEGER NOT NULL,
year_id INTEGER NOT NULL,
FOREIGN KEY (course_id) REFERENCES course(id),
FOREIGN KEY (year_id) REFERENCES year(id)
) ENGINE=InnoDB;

CREATE TABLE term (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
code CHAR(1) NOT NULL,
seq INTEGER NOT NULL,
name VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE student (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
name VARCHAR(255) NOT NULL,
email VARCHAR(255) NOT NULL,
password VARCHAR(255) NOT NULL,
form_id INTEGER,
verify VARCHAR(255),
FOREIGN KEY (form_id) REFERENCES form(id)
) ENGINE=InnoDB;

CREATE TABLE presentation (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
course_id INTEGER NOT NULL,
term_id INTEGER NOT NULL,
FOREIGN KEY (course_id) REFERENCES course(id),
FOREIGN KEY (term_id) REFERENCES term(id)
) ENGINE=InnoDB;

CREATE TABLE attendance (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
presentation_id INTEGER NOT NULL,
student_id INTEGER NOT NULL,
FOREIGN KEY (presentation_id) REFERENCES presentation(id),
FOREIGN KEY (student_id) REFERENCES student(id)
) ENGINE=InnoDB;

CREATE TABLE password_reset (
id INTEGER PRIMARY KEY AUTO_INCREMENT,
code VARCHAR(255),
student_id INTEGER NOT NULL,
FOREIGN KEY (student_id) REFERENCES student(id)
) ENGINE=InnoDB;
