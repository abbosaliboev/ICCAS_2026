# Edge AI-Based Real-Time Fall Detection and Alert System for Elderly People Living Alone

**Abbos Aliboev** (ali@chungbuk.ac.kr)<sup>1</sup>, **Damin Kim**<sup>1</sup>, **Jonghyuk Park**<sup>1</sup>, **Seongwoo Cho**<sup>2</sup>

<sup>1</sup>Chungbuk National University &nbsp;|&nbsp; <sup>2</sup>Inje University

---

## Abstract

As the proportion of the elderly population grows rapidly around the world, many countries are entering a super-aged society. In particular, France and South Korea have people aged 65 and older making up more than 20% of the total population. Falls among the elderly are emerging as an important social and medical issue [1].

In France, about 30% of people aged 65 and older experience a fall each year, and in South Korea, falls account for the highest proportion of all causes of injury. Falls among elderly people living alone frequently occur in home settings where caregivers cannot immediately check on them, making fast detection and response necessary.

Existing wearable sensor-based systems require users to wear the device at all times, which can be uncomfortable, and they cannot track full-body movement since they only measure one body part. In addition, cloud-based systems raise privacy concerns as video data is transmitted to external servers. To overcome this, there is a growing need for non-contact, camera-based fall detection systems.

In this study, we propose an **edge AI-based fall detection system** that uses a camera and an edge device to process video data directly on the device without sending it to external servers, thereby protecting user privacy, while detecting falls in real time and immediately notifying caregivers. The system uses pose estimation [2] and a skeleton-based classification model [3] to detect falls, and verifies detection through hip velocity analysis [4]. The system also provides reports that record fall location and time data, helping caregivers understand where and when falls occur most often, and take preventive measures.

The system is expected to serve as a safety solution for the elderly living alone, enabling family members to take immediate action, including contacting emergency services if needed.

In future work, we plan to collect additional fall data from elderly individuals and fine-tune the model to improve detection [5]. In addition, by collecting data and conducting heatmap analysis, it is possible to identify high-risk areas in environments such as hospitals where the risk of falls is high, thereby helping to prevent injuries.

---

## Keywords

`Elderly Care` `Fall Detection` `Real-Time` `Lightweight` `Pose Estimation` `Alert System`

---

## References

[1] World Health Organization. (2021). *Falls*. WHO Fact Sheet. https://www.who.int/news-room/fact-sheets/detail/falls

[2] Khanam, R., & Hussain, M. (2024). YOLOv11: An overview of the key architectural enhancements. *arXiv preprint arXiv:2410.17725*. https://arxiv.org/abs/2410.17725

[3] Yan, J., Wang, X., Shi, J., & Hu, S. (2023). Skeleton-based fall detection with multiple inertial sensors using spatial-temporal graph convolutional networks. *Sensors, 23*(4), 2153. https://doi.org/10.3390/s23042153

[4] Michaels, R., Barreira, T. V., Robinovitch, S. N., Sosnoff, J. J., & Moon, Y. (2025). Estimating hip impact velocity and acceleration from video-captured falls using a pose estimation algorithm. *Scientific Reports, 15*, 1558. https://doi.org/10.1038/s41598-025-85934-y

[5] Martinez-Villaseñor, L., Ponce, H., Mendez-Hernandez, J., Perez-Espinosa, H., Mitre-Hernandez, H., & Espinosa-Loera, R. (2019). UP-Fall detection dataset: A multimodal approach to fall detection. *Sensors, 19*(9), 1988. https://doi.org/10.3390/s19091988
