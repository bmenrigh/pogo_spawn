package main

import (
    "fmt"
	"strings"
	"bufio"
	"os"
	"strconv"
	"math"
	"gonum.org/v1/gonum/mat"
)

const MAXDEX = 790
var spawn_count int
var dex_count [MAXDEX + 1]uint32
var dex_name [MAXDEX + 1]string
var spawns map[string][]int
var dex_spawnpoints [][]int
var dex_vectors []*mat.VecDense

type cluster struct {
	Class int
	Dist []float64
	Uncer []float64
	Locked bool
}

var biome_name = []string{"unk", "cities", "forests", "mountains", "water", "north"}
var biome_seeds = [][]int{
	[]int{},                        // unk
	[]int{100, 137, 509, 568},      // cities
	[]int{56, 103, 618, 753},       // forests
	[]int{293, 303, 304, 527},      // mountains
	[]int{54, 79, 226, 592},        // water
	[]int{333, 495, 498, 501, 694}} // north


func main() {

	spawns = make(map[string][]int)

	input := bufio.NewScanner(os.Stdin)
    scanbuffer := make([]byte, 65536)
    input.Buffer(scanbuffer, 65536)

	fmt.Fprintf(os.Stderr, "Parsing spawn table from stdin\n")

	for {
		ok := input.Scan()
        if !ok {
            break
        }

		line := input.Text()

        if len(line) == 0 {
            continue
        }

		// 10000044331434888970	577	0	SOLOSIS	0	SFp0g0SJ19886	17	0.33658173680305	1.14284145832062	3	1683095727	9263391218195234816 0 37.33986876439833	-121.78200526297321
		fields := strings.Split(line, "\t")

		if len(fields) != 15 {
			fmt.Fprintf(os.Stderr, "Warning: got a line with unexpected (%d) number of fields: %s\n", len(fields), line)
			continue
		}

		dnum, err := strconv.Atoi(fields[1])

		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: got a line with unparsable dex number (%s): %s\n", fields[1], line)
			continue
		}

		// cellid, err := strconv.ParseUint(fields[11], 10, 64)

		// if err != nil {
		// 	fmt.Fprintf(os.Stderr, "Warning: got a line with unparsable cellid number (%s) with error %s: %s\n", fields[11], err.Error(), line)
		// 	continue
		// }

		lat, err := strconv.ParseFloat(fields[13], 64)

		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: got a line with unparsable lat number (%s) with error %s: %s\n", fields[13], err.Error(), line)
			continue
		}

		lon, err := strconv.ParseFloat(fields[14], 64)

		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: got a line with unparsable lon number (%s) with error %s: %s\n", fields[14], err.Error(), line)
			continue
		}

		spstr := fmt.Sprintf("[%.04f, %.04f]", lat, lon)
		//fmt.Fprintf(os.Stderr, "key %s\n", spstr)

		dex_count[dnum]++

		if dex_name[dnum] == "" {
			dex_name[dnum] = fields[3]
		}

		_, ok = spawns[spstr]
		if !ok {
			spawns[spstr] = make([]int, MAXDEX + 1)
		}

		spawns[spstr][dnum]++

		spawn_count++
	}

	fmt.Fprintf(os.Stderr, "Got %d spawns across %d spawnpoints\n", spawn_count, len(spawns))

	fmt.Fprintf(os.Stderr, "Building species id to spawnpoint vectorspace\n")

	dex_spawnpoints = make([][]int, MAXDEX + 1)
	for i, _ := range dex_spawnpoints {
		dex_spawnpoints[i] = make([]int, len(spawns))
	}

	spidx := 0
	for sp, d := range spawns {
		for i, _ := range d {
			dex_spawnpoints[i][spidx] += spawns[sp][i]
		}

		spidx++
	}

	dex_vectors = make([]*mat.VecDense, MAXDEX + 1)
	for i, _ := range dex_spawnpoints {
		fs := make([]float64, len(dex_spawnpoints[i]))
		for j := 0; j < len(fs); j++ {
			fs[j] = float64(dex_spawnpoints[i][j])
		}

		dex_vectors[i] = mat.NewVecDense(len(fs), fs)
	}

	// fmt.Fprintf(os.Stderr, "Comparing angles in vectorspace\n")
	// for i := 0; i <= MAXDEX; i++ {
	// 	if dex_count[i] < 10000 {
	// 		continue
	// 	}
	// 	for j := i + 1; j <= MAXDEX; j++ {
	// 		if dex_count[j] < 10000 {
	// 			continue
	// 		}

	// 		thetaij := vec_theta(dex_vectors[i], dex_vectors[j])

	// 		fmt.Fprintf(os.Stderr, "theta simularity for %d (%s) and %d (%s): %.06f\n", i, dex_name[i], j, dex_name[j], thetaij);
	// 	}
	// }

	cluster_spawns(5)
}


func vec_theta(a, b *mat.VecDense) float64 {

	costheta := mat.Dot(a, b) / (mat.Norm(a, 2) * mat.Norm(b, 2))

	// fix tiny float rounding problem at 1.0
	if costheta > 1.0 {
		costheta = 1.0
	}

	return math.Acos(costheta)
}


func cluster_spawns(numc int) {

	dex_class := make([]cluster, MAXDEX + 1)

	if numc < len(biome_seeds) - 1 {
		panic("Not enough clusters")
	}

	for i, _ := range dex_class {
		dex_class[i].Class = 0
		dex_class[i].Dist = make([]float64, numc + 1)
		dex_class[i].Uncer = make([]float64, numc + 1)
	}

	for c, l := range biome_seeds {
		for _, d := range l {
			dex_class[d].Class = c
			dex_class[d].Locked = true
		}
	}

	class_vector := make([]*mat.VecDense, numc + 1)
	old_class_vector := make([]*mat.VecDense, numc + 1)
	class_vector_change := make([]float64, numc + 1)

	updated := -1
	round := 0
	for updated != 0 {
		updated = 0
		round++

		// Make new mean class vectors
		for i := 1; i <= numc; i++ {
			old_class_vector[i] = class_vector[i]
			class_vector[i] = mat.NewVecDense(len(dex_spawnpoints[0]), nil)
		}

		// compute the mean for each class
		for d, _ := range dex_class {
			if dex_class[d].Class != 0 {
				class_vector[dex_class[d].Class].AddVec(class_vector[dex_class[d].Class], dex_vectors[d])
			}
		}

		// find the class vector change
		for i := 1; i <= numc; i++ {
			if old_class_vector[i] != nil {
				class_vector_change[i] = vec_theta(class_vector[i], old_class_vector[i])
				fmt.Fprintf(os.Stderr, "Updated class %d mean vector by %.05f degrees\n", i, class_vector_change[i] * 180 / math.Pi)
			}
		}

		for d, _ := range dex_class {
			// Add uncertainty from the class mean changing
			for c, _ := range dex_class[d].Uncer {
				dex_class[d].Uncer[c] += class_vector_change[c]
			}

			// If any class needs updating do current class first
			if dex_class[d].Class != 0 && dex_class[d].Uncer[dex_class[d].Class] > 0.0 {
				for c, _ := range dex_class[d].Dist {
					if c != 0 && c != dex_class[d].Class {
						if dex_class[d].Dist[dex_class[d].Class] + dex_class[d].Uncer[dex_class[d].Class] >= dex_class[d].Dist[c] - dex_class[d].Uncer[c] {
							dex_class[d].Dist[dex_class[d].Class] = vec_theta(dex_vectors[d], class_vector[dex_class[d].Class])
							dex_class[d].Uncer[dex_class[d].Class] = 0.0
							break
						}
					}
				}
			}

			// Any class that is now possibly close enough needs a distance check
			for c, _ := range dex_class[d].Dist {
				if c != 0 && c != dex_class[d].Class {
					if dex_class[d].Class == 0 ||
						dex_class[d].Dist[dex_class[d].Class] + dex_class[d].Uncer[dex_class[d].Class] >= dex_class[d].Dist[c] - dex_class[d].Uncer[c] {
						dex_class[d].Dist[c] = vec_theta(dex_vectors[d], class_vector[c])
						dex_class[d].Uncer[c] = 0.0
					}
				}
			}

			if dex_class[d].Locked == false {
				// Find closest class
				mindist := 3.0 // must be > Pi / 2
				bestclass := 0
				for c, _ := range dex_class[d].Dist {
					if c != 0 && dex_class[d].Dist[c] < mindist {
						bestclass = c
						mindist = dex_class[d].Dist[c]
					}
				}

				if bestclass != dex_class[d].Class {
					dex_class[d].Class = bestclass
					updated++
				}
			}
		}

		fmt.Fprintf(os.Stderr, "Clustering round %d: updated %d species\n", round, updated)
	}

	// Now make sure the distance to each class has no uncertainty
	for d, _ := range dex_class {
		if dex_class[d].Uncer[dex_class[d].Class] > 0.0 {
			dex_class[d].Dist[dex_class[d].Class] = vec_theta(dex_vectors[d], class_vector[dex_class[d].Class])
			dex_class[d].Uncer[dex_class[d].Class] = 0.0
		}
	}

	for c := 1; c <= numc; c++ {
		fmt.Fprintf(os.Stderr, "\nCluster class %d (%s):\n", c, biome_name[c]);
		for d, _ := range dex_class {
			if dex_class[d].Class == c {
				fmt.Fprintf(os.Stderr, "%d (%s): %0.5f degrees from class mean\n", d, dex_name[d], dex_class[d].Dist[dex_class[d].Class] * 180 / math.Pi);
			}
		}
	}
}
