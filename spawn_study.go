package main

import (
    "fmt"
	"strings"
	"bufio"
	"os"
	"strconv"
	"gonum.org/v1/gonum/mat"
)

const MAXDEX = 790
var spawn_count int
var dex_count [MAXDEX + 1]uint32
var dex_name [MAXDEX + 1]string
var spawns map[int64][]int
var dex_spawnpoints [][]int
var dex_vectors []*mat.VecDense

func main() {

	spawns = make(map[int64][]int)

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

		spnum, err := strconv.ParseInt(fields[10], 10, 64)

		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: got a line with unparsable spawnpoint number (%s): %s\n", fields[10], line)
			continue
		}

		dex_count[dnum]++

		if dex_name[dnum] == "" {
			dex_name[dnum] = fields[3]
		}

		_, ok = spawns[spnum]
		if !ok {
			spawns[spnum] = make([]int, MAXDEX + 1)
		}

		spawns[spnum][dnum]++

		spawn_count++
	}

	fmt.Fprintf(os.Stderr, "Got %d spawns across %d spawnpoints\n", spawn_count, len(spawns))

	fmt.Fprintf(os.Stderr, "Building species id to spawnpoint vectorspace\n")

	dex_spawnpoints = make([][]int, MAXDEX + 1)
	for i := range dex_spawnpoints {
		dex_spawnpoints[i] = make([]int, len(spawns))
	}

	spidx := 0
	for sp, d := range spawns {
		for i := range d {
			dex_spawnpoints[i][spidx] += spawns[sp][i]
		}

		spidx++
	}

	dex_vectors = make([]*mat.VecDense, MAXDEX + 1)
	for i := range dex_spawnpoints {
		fs := make([]float64, len(dex_spawnpoints[i]))
		for j := 0; j < len(fs); j++ {
			fs[j] = float64(dex_spawnpoints[i][j])
		}

		dex_vectors[i] = mat.NewVecDense(len(fs), fs)
	}

	fmt.Fprintf(os.Stderr, "Comparing angles in vectorspace\n")
	for i := 0; i <= MAXDEX; i++ {
		if dex_count[i] < 10000 {
			continue
		}
		for j := i + 1; j <= MAXDEX; j++ {
			if dex_count[j] < 10000 {
				continue
			}

			cosij := cos_vec(dex_vectors[i], dex_vectors[j])

			fmt.Fprintf(os.Stderr, "cos simularity for %d (%s) and %d (%s): %.06f\n", i, dex_name[i], j, dex_name[j], cosij);
		}
	}
}


func cos_vec(a, b *mat.VecDense) float64 {

	dp := mat.Dot(a, b)

	return dp / (mat.Norm(a, 2) * mat.Norm(b, 2))
}
