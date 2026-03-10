  #import "@preview/ilm:2.0.0": *

#set text(
  lang: "en",
  font: "Libertinus Serif",
  size: 12pt,
)
#set par(justify: true, leading: 0.64em)

#show: ilm.with(
  title: [Behavioural Research in Statistical Methods - Project Report - 1],
  authors: (
    "Sambu Aneesh (2023121012)",
    "Renu Sree Vyshnavi (2022101035)",
    "Pavan Harshit (2025701057)",
  ),
  abstract: [
    In this phase, we present a concise exploratory analysis of the MST data. We describe the data, visualize the main patterns, and identify what possibly can be done in the next phase.
  ],
  cover-page: [
    #align(left + horizon)[
      #v(7em)
      #text(1.9em, weight: "bold")[Behavioural Research in Statistical Methods]
      #text(1.9em, weight: "bold")[Project Report - 1]
      #v(1.2em)
      *Team Name:* Earphones\
      *Experiment:* Mnemonic Similarity Task (MST)
      #v(1.2em)
      Sambu Aneesh (2023121012)\
      Renu Sree Vyshnavi (2022101035)\
      Pavan Harshit (2025701057)
      #v(1.4em)
      In this phase, we present a concise exploratory analysis of the MST data.\
      We describe the data, visualize the main patterns, and identify what possibly can be done in the next phase.
    ]
  ],
  preface: none,
  bibliography: none,
  table-of-contents: none,
  chapter-pagebreak: false,
  figure-index: (enabled: false),
  table-index: (enabled: false),
  listing-index: (enabled: false),
)

= Introduction
In this project, we are looking at how memory functions around event boundaries using Mnemonic Similarity Task (MST) data. This is straightforward investigation, however, we want to know does the memory of an image shift just because it appeared immediately before or after a boundary? And does the way we create that boundary matter?

This experiment essentially brings together two separate corners of memory research. The first concept is event segmentation. This theory suggests that people naturally chop up continuous, everyday experiences into bite-sized events. These mental boundaries ultimately shape how we encode and update our memories #link(<ref-zacks2007event>)[(Zacks and Swallow, 2007)] #link(<ref-swallow2009boundaries>)[(Swallow et al., 2009)]. The second major component is the MST. This task is a staple for studying memory pattern separation. Rather than just testing basic recognition, the MST forces participants into the much harder job of spotting tricky, fine-grained 'lures' #link(<ref-stark2019mst>)[(Stark et al., 2019)] #link(<ref-yassa2011pattern>)[(Yassa and Stark, 2011)]. In the original paper we are targeting, the most noticeable effect went in two directions: people were worse at recognizing target items shown after a boundary, but they were actually better at spotting lures shown before a boundary, at least when multiple cues supported that boundary #link(<ref-morse2023event>)[(Morse et al., 2023)].

The MST data we are working with comes in three task variations: Item Shift Only (`item_only`), Item + Task Shift (`both`), and Task Shift Only (`task_only`). The experiment swapped out the standard encoding prompt ("Natural vs. Manmade") for a custom judgment: "Will it fit in a shoebox?". Across the dataset, our main independent variables are the condition and the boundary position (`post`, `mid`, or `pre`). For our dependent variables, we are tracking encoding response time, recognition memory (REC), and lure discrimination (LDI).

Right now, our goal is exploratory. We build up a description of the data, verify if the basic task manipulations actually worked, and pinpoint which effects look strong enough to rigorously test in the next phase.

== Working questions
1. Do event boundaries actually drag out encoding response times?
2. Is it harder for participants to recognize items that show up immediately after a boundary, compared to items sitting right in the middle or just before it?
3. Do pre-boundary items show better lure discrimination?
4. Does the pattern differ across `item_only`, `both`, and `task_only`?
5. Are the lure bins actually working? Meaning, as the visual lures get easier, do participants get better at spotting them?


== Initial hypotheses
1. *Encoding RT*
   `H0:` Boundary position does not affect encoding RT.
   `H1:` Post-boundary items will be slower, especially when the task rule changes.
2. *Recognition memory*
   `H0:` REC does not differ across `post`, `mid`, and `pre`.
   `H1:` Post-boundary REC will be lower than mid-event REC, strongest in the Item + Task Shift condition.
3. *Lure discrimination*
   `H0:` LDI does not differ across `post`, `mid`, and `pre`.
   `H1:` Pre-boundary LDI may be higher than mid-event or post-boundary LDI, following the target paper.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    inset: 6pt,
    stroke: (x, y) => if y == 0 { 0.8pt + rgb("#6c757d") } else { 0.3pt + rgb("#d9d9d9") },
    table.header(
      [Condition], [Paired $n$], [Encoding trials], [Test trials], [Accuracy summary],
    ),
    [Item Shift Only], [56], [280], [150], [0.926],
    [Item + Task Shift], [49], [280], [150], [0.947],
    [Task Shift Only], [53], [280], [150], [0.943],
  ),
  caption: [Cleaned sample sizes and participant-level accuracy summaries after pairing raw task and test files. The Item Shift Only value was recalculated from scene trials using the provided `scenes_mapping.txt` file (`n = 56`). The Item + Task Shift and Task Shift Only values come from the task CSV summary field and were available for `48/49` and `52/53` paired participants, respectively. Because these values were derived differently across conditions, they are descriptive only and should not be treated as directly comparable outcome measures.],
)

= Methods
== Data preparation
All of the raw CSV files were read straight from the three `MST_Data` folders. The participant served as our analytical unit. This is in line with the trial -> subject -> group structure that was covered in class: we cleaned the trials, summarized them within the subject, and then compared the conditions. In order to avoid treating individual trials as separate observations when the true comparison of interest was between participants and conditions, we purposefully did this.

We matched each participant's task and test files one by one. If the participant had only one task-test pair in the clean files, we used this pair as is. If the participant had duplicate files in the raw data, we paired the latest test file with the previous task file. If the participant had only a task file or only a test file, they were not included in the analysis. In other words, we treated the participants with incomplete sessions as having missing data and hence dropped them.

We kept the 280 non-practice trials for encoding. We called the first item in a block "post," the last item "pre," and the five items in the middle "mid" because each event had 7 items. We figured out the response time by looking at the in-trial response when it was available or by adding 3 to the post-stimulus RT when the response was recorded after the image was turned off.

We kept the 150 non-empty trials for test data. We used the filename of each test image to tell if it was a target, lure, or foil. We also used the `position_of_stimuli` field to find out if the original studied item came from a `post`, `mid`, or `pre` position.

== Variables and measures
Mean response time and response completeness by boundary position were the primary encoding variables. $"REC" = P("old" | "Target") - P("old" | "Foil")$ and $"LDI" = P("similar" | "Lure") - P("similar" | "Foil")$ were the primary memory variables.

These are the main scores that the experiment brief asks for. Additionally, they naturally correspond to the distinction between operationalized dependent variables and basic descriptive measures taught in class: LDI captures high-fidelity lure discrimination, whereas REC captures bias-corrected target recognition.

A sensitivity check was also added. We calculated an alternate lure score by combining `new` and `similar` into a more comprehensive rejection response since the replication paper employed an old/new-style lure rejection logic #link(<ref-morse2023event>)[(Morse et al., 2023)]. This was only used to see if scoring choice affected the main LDI result.

Lastly, we attached a lure-similarity bin to each image using the provided object and scene bin files. This made it possible for us to examine whether discrimination improved as lures became less similar.

== Statistical strategy
In this phase, statistical analysis was carried out with special focus on clarity and simplicity. Descriptive analysis was carried out before moving on to inferential analysis. The means of the participants were visualized first, followed by the use of repeated measures ANOVA in each condition. If the results from the ANOVA were found informative, then the use of Holm-corrected paired t-tests was carried out for post hoc analysis. This was in line with the precautionary measures taken in the class, where the use of post hoc analysis was emphasized as necessary after the conduct of multiple tests.

In order to carry out cross-condition comparison, three contrast scores were calculated. They were post-minus-mid encoding RT, post-minus-mid REC, and pre-minus-mid LDI. A one-way ANOVA and Holm-corrected Welch t-tests were carried out on the three conditions. Throughout the report, the focus was on the direction of the results rather than complex modeling.

In the visualization phase, the use of summary visualization was complemented by the use of structure-revealing visualization. This was in line with the class's emphasis on the use of figures such that they are informative at the group level and also carry enough details to reveal the underlying structure and potential problems in the data.

= Results
== Dataset overview
We maintained 56 paired participants in the item shift only condition, 49 in the item and task shift condition, and 53 in the task shift only condition.

#figure(
  image("figures/phase1_dataset_overview.png", width: 100%),
  caption: [Dataset overview. The left panel shows the total number of complete task-test pairs included in the analysis, and the right panel shows the classification of cases as clean, incomplete, or requiring resolution of duplicate files.],
)

As a preliminary quality control procedure, we utilized a response-profile heat map approach. The results indicated that the majority of targets were classified as old, lure items as similar, and foils as new. Although this is a basic step in the process, it is an important one in showing that the participants utilized the response categories in a logical manner before moving on to more complex analyses.
The participants utilized the expected response categories.

#figure(
  image("figures/phase1_response_profiles.png", width: 100%),
  caption: [Average response profiles for the different conditions, types of trials, and encoding positions. The diagonal pattern shows that participants utilized the expected response category for each type of item.],
)

== Boundaries clearly slowed encoding when the task rule changed
The strongest effect found in the MST data set related to the encoding RT pattern. In the Item + Task Shift condition, boundary position significantly affected the response time, $F(2, 96) = 68.36$, $p < .001$. The post-boundary items were significantly slower compared to the mid-event and pre-boundary items, as shown in the Holm correction results. Although the same pattern of results emerged in the Task Shift Only condition, the main effect of boundary position was significant, $F(2, 104) = 60.21$, $p < .001$. In the Item Shift Only condition, the RT effect was not significant, $F(2, 110) = 2.22$, $p = .114$.

This is an important finding since it shows that the boundary manipulation has its strongest effect when the task rule is shifted. It is consistent with the idea of event segmentation in which boundaries temporarily raise the processing demands #link(<ref-swallow2009boundaries>)[(Swallow et al., 2009)].

#figure(
  image("figures/phase1_encoding_rt.png", width: 100%),
  caption: [Mean encoding RT by boundary position for each condition. Subtle lines indicate individual participant data, and colored markers show condition means with 95% CI.],
)

== Recognition showed a post-boundary cost
Recognition was less consistent than RT, but a clear pattern still emerged. In Item + Task Shift, REC changed depending on the boundary position, $F(2, 96) = 6.45$, $p = .002$. After the Holm correction, post-boundary REC was lower than both mid-event REC and pre-boundary REC. In Task Shift Only, REC also changed overall, $F(2, 104) = 4.62$, $p = .012$, though the only corrected pairwise effect was post-boundary lower than pre-boundary. In Item Shift Only, REC did not vary reliably, $F(2, 110) = 0.21$, $p = .814$.

So the strongest memory result in this phase is not about pre-boundary lure benefits. It is a post-boundary recognition cost, especially when the boundary is marked by both item and task cues.

#figure(
  image("figures/phase1_memory_indices.png", width: 100%),
  caption: [Primary memory indices by boundary position and condition. REC showed its clearest post-boundary cost in the item + task condition.],
)

== The expected pre-boundary LDI advantage did not appear clearly
Under this primary three-response scoring model used in this experiment, no boundary effect was obtained for any of these three conditions: Item Shift Only, $F(2, 110) = 0.40$, $p = .675$; Item + Task Shift, $F(2, 96) = 1.40$, $p = .252$; Task Shift Only, $F(2, 104) = 0.55$, $p = .577$.

A sensitivity analysis was conducted on these results to determine if this lack of a boundary effect was a function of a scoring model artifact. Even when extending this lure rejection measure to include both `new` items and `similar` items, no pre-boundary advantage re-emerged in these results. In fact, only one corrected pairwise effect was obtained in the Item + Task Shift condition, demonstrating that mid-event performance exceeded pre-boundary performance. The results obtained in this phase lead to a conclusion that the results obtained in the MST data set fail to support a clean replication of the pre-boundary lure discrimination directional effect reported by #link(<ref-morse2023event>)[(Morse et al., 2023)].

== Lure bins yielded expected results
While the boundary-specific LDI pattern was limited in magnitude, the lure bins were interpretable in all three conditions. In addition, discrimination increased as the lure moved further away from the target, consistent with expectations for valid MST data and thus task quality, in spite of the limited boundary effects #link(<ref-stark2019mst>)[(Stark et al., 2019)] #link(<ref-yassa2011pattern>)[(Yassa and Stark, 2011)].

#figure(
  image("figures/phase1_lure_bins.png", width: 100%),
  caption: [Lure-bin curves by condition and encoding position. In all three conditions, discrimination improved as lures became less similar.],
)

== Summary of the exploratory pattern
In conclusion, the results of the MST data have three significant implications for practice:

1. The boundary manipulation has a significant impact when the task rule is changed.
2. The strongest memory effect is observed as a post-boundary recognition cost, with the strongest effects in the item + task shift condition.
3. Lure discrimination follows the conventional MST pattern, with discrimination increasing as the lure moved away from the target in the lure bins, but failed to show the expected pre-boundary advantage as suggested in the target study.

This is beneficial at this stage in the analysis as it helps to reduce the possible space of where the next step in analysis should focus and where the strongest effects are expected.

= Conclusion and future directions
In this phase, we established a reproducible starting point for the MST data. We cleaned the raw files, documented pairing decisions, visualized the main variables, and used simple inferential tests that are easy to interpret.

Our main conclusion is that the data support a strong boundary-related processing effect and a moderate post-boundary recognition cost, but not a clear pre-boundary LDI benefit. In the next phase, the strongest step is to test the post-boundary recognition effect more directly, especially in the Item + Task Shift condition. A second priority is to examine whether subject-level heterogeneity or boundary implementation explains the weak LDI pattern.

#pagebreak()

= Codebase and contributions
The source code for this project is available at #link("https://github.com/ch-pavan/brim")[https://github.com/ch-pavan/brim].

This phase was done collaboratively, with all three members contributing across reading, analysis, checking, and writing.

1. *Sambu Aneesh:* Worked on the methods and background sections and also involved in the framing of primary exploratory questions about the study. He also analyzed the raw data structure and scaffolding the entire project for easier collaboration and worked with Renu and Pavan to decide upon the scoring choices.
2. *Renu Sree Vyshnavi:* Mainly worked on the results section and findings interpretation. She also went through the MST literature and project brief, helping guide the overall project plan. She then was involved with us in preprocessing the data and interpreting the output figures and verifying the results.
3. *Pavan Harshit:* Worked on the final report and integrated the analysis code and figures. He ran his own analyses, matched the research questions, and guided the total structure of the project. He cross verified course content and was involved in the primary decision making of which metrics to choose and analyse from.

#text(weight: "bold")[References]
#set par(leading: 0.38em)
#text(size: 7.5pt)[
[1] J. M. Zacks and K. M. Swallow, "Event Segmentation," *Current Directions in Psychological Science*, 16(2), 80-84, 2007. <ref-zacks2007event>\
[2] K. M. Swallow, J. M. Zacks, and R. A. Abrams, "Event Boundaries in Perception Affect Memory Encoding and Updating," *Journal of Experimental Psychology: General*, 138(2), 236-257, 2009. <ref-swallow2009boundaries>\
[3] S. M. Stark, C. B. Kirwan, and C. E. L. Stark, "Mnemonic Similarity Task: A Tool for Assessing Hippocampal Integrity," *Trends in Cognitive Sciences*, 2019. <ref-stark2019mst>\
[4] M. A. Yassa and C. E. L. Stark, "Pattern Separation in the Hippocampus," *Trends in Neurosciences*, 34(10), 515-525, 2011. <ref-yassa2011pattern>\
[5] S. J. Morse, A. B. Karagoz, and Z. M. Reagh, "Event Boundaries Directionally Influence Item-Level Recognition Memory," 2023. <ref-morse2023event>
]
