# -*- coding: utf-8 -*-

import json

cdef list wins

with open('resources/wins.txt') as f:
    wins = map(set,[map(tuple,_) for _ in json.load(f)])
    
DEF inf = float('infinity')

cdef float negamax(object game, int depth, int origDepth, object scoring, 
              float alpha=+inf, float beta=-inf):
    cdef float alphaOrig, bestValue, move_alpha
    cdef int score
    cdef list possible_moves
    cdef object state
    cdef tuple move
    
    alphaOrig = alpha                        
    
    if (depth == 0) or game.is_over():
        score = scoring()
        if score == 0:
            return score
        else:
            return  (score - 0.01*depth*abs(score)/score)

    possible_moves = game.possible_moves()
    state = game
    best_move = possible_moves[0]
    if depth == origDepth:
        state.ai_move = possible_moves[0]
        
    bestValue = -inf
    
    for move in possible_moves:      
        game.make_move(move)
        game.switch_player()
        
        move_alpha = - negamax(game, depth-1, origDepth, scoring,
                               -beta, -alpha)
        game.switch_player()
        game.unmake_move(move)
        
        bestValue = max(bestValue, move_alpha)
        if  alpha < move_alpha :
            alpha = move_alpha
            best_move = move
            if depth == origDepth:
                state.ai_move = move
            if (alpha >= beta):
                break

    return bestValue

        
cdef class Negamax:
    cdef int depth
    cdef float alpha, win_score
    
    def __init__(self, int depth):       
        self.depth = depth
        self.win_score = inf
    
    def __call__(self, object game):
        self.alpha = negamax(game, self.depth, self.depth, game.scoring,
                     -self.win_score, +self.win_score)
        return game.ai_move

cdef class AI_Player:
    cdef object AI_algo
    cdef str name
    cdef dict move

    def __init__(self, object AI_algo):
        self.AI_algo = AI_algo
        self.name='AI'
        self.move = {}

    cpdef ask_move(self, object game):
        return self.AI_algo(game)

cdef tuple index4d(int i):
    cdef int x, y, z, w
    x = i % 5
    y = ((i-x)/5) % 5
    z = ((i - y*5 - x) / 25) % 5
    w = ((i - z*25 - y*5 - x) / 125) % 5
    return (x, y, z, w)

cdef tuple check_lines(list player_moves, list opponent_moves):
    cdef list player_lines, opponent_lines
    cdef object pm, om
        
    pm = set(map(tuple,player_moves))
    om = set(map(tuple,opponent_moves))
    player_lines = [len(pm & x) for x in wins]
    opponent_lines = [len(om & x) for x in wins]
    return player_lines, opponent_lines

cdef class Tic4D:
    cdef list players
    cdef int nplayer
    cdef tuple last_move
    cdef public dict board, move_list
    cdef public object ai_move

    def __init__(self, list players):
        self.players = players
        self.nplayer = 1
        self.board = {index4d(x):0 for x in xrange(625)}
        self.move_list = {1:[], -1:[], 'all':[]}
        self.last_move = self.ai_move = None
    
    property nopponent:
        def __get__(self): return 2 if (self.nplayer == 1) else 1
    
    property player:
        def __get__(self): return self.players[self.nplayer- 1]
    
    property opponent:
        def __get__(self): return self.players[self.nopponent - 1]
    
    cpdef switch_player(self):
        self.nplayer = self.nopponent

    property pl:
        def __get__(self): return [0,1,-1][self.nplayer]
    
    property op:
        def __get__(self): return [0,1,-1][self.nopponent]
    
    cpdef list possible_moves(self):
        return [x for x in self.board if self.board[x] == 0]
    
    cpdef make_move(self, object move):
        self.board[tuple(move)] = self.pl
        self.move_list[self.pl].append(move)
        self.move_list['all'].append(move)
        self.last_move = tuple(move)
    
    cpdef bint win(self):
        cdef list pmoves, omoves, pm, om
        pmoves, omoves = self.move_list[self.pl], self.move_list[self.op]
        if len(pmoves) < 5:
            return False
        pm, om = check_lines(pmoves, omoves)
        return 5 in pm
    
    cpdef list neighbors(self, list point, int rad=1):
        cdef list radius, neighborhood
        cdef tuple dims, shift
        cdef int i, j, k, l
        radius = list(xrange(-rad,rad+1))
        dims = (5,5,5,5)
        neighborhood = []
        for i in radius:
            if (point[0] + i < 0 or point[0] + i > dims[0] - 1): continue
            for j in radius:
                if (point[1] + j < 0 or point[1] + j > dims[1] - 1): continue
                for k in radius:
                    if (point[2] + k < 0 or point[2] + k > dims[2] - 1): continue
                    for l in radius:
                        if (point[3] + l < 0 or point[3] + l > dims[3] - 1): continue
                        shft = (i, j, k, l)
                        x, y, z, w = [point[x] + shft[x] for x in range(4)]
                        if self.board[x, y, z, w] == self.pl and shft != (0, 0, 0, 0):
                            neighborhood.append((x, y, z, w))
        return neighborhood
    
    cpdef unmake_move(self, object move):
        cdef int pl
        pl = [0,1,-1][self.nplayer]
        self.board[tuple(move)] = 0
        self.move_list[pl].remove(move)
        assert self.move_list['all'].pop() == move, 'Can only undo last move'
    
    cpdef bint is_over(self):
        return (self.possible_moves() == []) or self.win()
        
    cpdef int scoring(self):
        cdef list cmoves, player_lines, opponent_lines
        cdef int n, m, score
        cdef object mm
        cmoves = self.move_list[self.pl]
        n = len(cmoves)
        if n == 0:
            return 0
        if n == 1:
            mm = cmoves[0]
            score = 12
            for m in mm:
                score -= abs(m - 2)
            return score
        player_lines, opponent_lines = check_lines(cmoves, self.move_list[self.op])
        score = 0
        for i in range(len(wins)):
            if player_lines[i] and not opponent_lines[i]:
                score += (player_lines[i]**2 + 100*(player_lines[i] == 5))
            elif opponent_lines[i] and not player_lines[i]:
                score -= (opponent_lines[i] + 100*(opponent_lines[i] == 5))
        return score
    
    cpdef bint play(self, object move):
        if self.is_over():
            return False
        self.make_move(move)
        if self.win():
            return True
        self.switch_player()
        return False

cdef class HumanPlayer:
    pass