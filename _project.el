
(load-this-project
 `( (:ruby-executable ,*ruby-1.9-executable*)
    (:run-project-command (ruby-run-file ,(concat (project-base-directory) "RunMain.rb")))
    (:build-function project-compile-with-command)
    (:compile-command "c:/Ruby192/bin/rake")
    (:ruby-args ("-I."))
    ) )

