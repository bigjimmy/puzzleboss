
%.class: %.java
	javac $< -sourcepath .:/canadia/google/gdata/java/src/:/canadia/google/gdata/java/ -cp .:/canadia/google/gdata/java/classes/:/canadia/google/gdata/java/sample/appsforyourdomain/:/canadia/google/commons-cli-1.2/commons-cli-1.2.jar:/usr/share/tomcat6/lib/servlet-api.jar:/usr/share/java/gnumail.jar:/usr/share/java/activation.jar:/canadia/google/gdata/java/deps/google-collect-1.0-rc1.jar:/canadia/google/gdata/java/deps/jsr305.jar -Xlint:unchecked  -Xlint:deprecation 

all: AddPuzzleSpreadsheet.class AddPuzzleDocument.class AddRound.class AddHunt.class DeleteEntries.class AddDomainUser.class DeleteDomainUser.class ChangeUserPass.class

