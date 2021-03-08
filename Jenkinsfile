library "alauda-cicd"
def language = "golang"
AlaudaPipeline {
    config = [
        agent: 'golang-high',
        folder: '.',
        scm: [
            credentials: 'acp-acp-gitlab'
        ],
        chart: [
            [
                chart: "topolvm",
                project: "acp",
                pipeline: "chart-topolvm",
                component: "topolvm",
            ]
        ],
        docker: [
            repository: "acp/topolvm",
            credentials: "alaudak8s",
            context: ".",
            dockerfile: "Dockerfile",
            armBuild: false,
        ],
        sonar: [
            binding: "sonarqube"
        ],
        sec: [
            enabled: true,
            block: false,
            lang: 'go',
            scanMod: 1,
            customOpts: ''
        ],
	notification: [
	    name: "default"
	],
    ]
    env = [
        GO111MODULE: "on",
    ]
    steps = [

    ]

}
