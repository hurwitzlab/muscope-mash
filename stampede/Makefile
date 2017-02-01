APP = muscope-mash-0.0.2

test: clean
	sbatch test.sh

clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.param -o -name launcher-\* \) -exec rm {} \;

upload: clean
	files-upload -F $(WORK)/$(APP) kyclark/applications

update:
	apps-addupdate -F app.json

job:
	jobs-submit -F job.json

scriptsgz:
	(cd scripts && tar cvf ../scripts.tgz *)
